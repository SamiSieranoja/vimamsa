require "tmpdir"
require "rbconfig"

# custom.rb is loaded in two phases (see call_custom_after_init in editor.rb):
# the body of the file runs before Grep.init/FileManager.init/module loading, so
# that its cnf.* settings are visible to them, and hook_custom_after_init runs
# after everything is loaded, so it can bind keys for the modes they registered.
#
# That ordering can only be observed while an editor starts up, so this test
# boots a second editor process with VMA_USER_DIR pointing at a generated config
# and lets a probe test inside that process check the resulting binding tree.
class TestCustomTwoPhase < VmaTest
  CUSTOM_RB = <<~'RUBY'
    # Phase 1: must be visible to FileManager.init, which registers the
    # experimental fexp bindings ("fexp d d" etc.) only when this is set.
    cnf.fexp.experimental = true

    # Phase 2: the fexp mode does not exist while the body of this file runs.
    def hook_custom_after_init
      reg_act(:_zz_probe_archive, proc { }, "probe")
      bindkey "fexp , x", :_zz_probe_archive
    end
  RUBY

  PROBE_RB = <<~'RUBY'
    class TestZzTwoPhaseProbe < VmaTest
      def test_hook_custom_after_init_bound_to_fexp
        assert_eq ["fexp , x"], paths_of(:_zz_probe_archive),
          "hook_custom_after_init should bind to the fexp mode, not leak elsewhere"
      end

      def test_phase1_settings_reached_module_init
        assert_eq ["fexp d d"], paths_of(:fexp_cut_file),
          "cnf.fexp.experimental from the body of custom.rb should reach FileManager.init"
      end

      def paths_of(action)
        found = []
        walk = lambda { |state, path|
          state.children.each { |c|
            p2 = path + [c.key_name]
            found << p2.join(" ") if c.action == action
            walk.call(c, p2)
          }
        }
        vma.kbd.root.children.each { |mode| walk.call(mode, [mode.key_name]) }
        found
      end
    end
  RUBY

  def test_custom_rb_phases_run_in_order
    # Set in the child so a copy of this test file there can never recurse.
    skip "nested editor run" if ENV["VMA_TEST_CHILD"]

    Dir.mktmpdir("vimamsa-two-phase-") do |dir|
      File.write(File.join(dir, "custom.rb"), CUSTOM_RB)
      probe = File.join(dir, "test_zz_two_phase_probe.rb")
      File.write(probe, PROBE_RB)

      args = [File.expand_path("exe/run_tests.rb", vma_root), probe]
      # Reuse this run's display when it is already headless; open the child on
      # its own invisible display when we are on the real desktop, so it cannot
      # steal focus from e2e tests.
      backend = Gdk::Display.default&.gtype&.name.to_s
      args << "--headless" if backend.include?("Wayland")

      env = { "VMA_USER_DIR" => dir, "VMA_TEST_CHILD" => "1" }
      out_r, out_w = IO.pipe
      pid = begin
        Process.spawn(env, RbConfig.ruby, *args, chdir: vma_root,
                      out: out_w, err: out_w)
      rescue SystemCallError => e
        out_r.close
        out_w.close
        skip "could not start child editor: #{e}"
      end
      out_w.close
      output = out_r.read
      out_r.close
      _, status = Process.waitpid2(pid)

      assert status.success?, "child editor run failed:\n#{output}"
    end
  end

  private

  def vma_root
    File.expand_path("..", File.dirname(__FILE__))
  end
end

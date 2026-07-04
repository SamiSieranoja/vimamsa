class TestCrashHandler < VmaTest

  # report() writes a .txt and .json into the crash dir, then we clean up.
  def test_report_writes_files
    base = Vimamsa::CrashHandler.report("test", RuntimeError.new("kaboom"))
    assert !base.nil?, "report should return a base path"
    txt = "#{base}.txt"
    json = "#{base}.json"
    assert File.exist?(txt), "crash .txt should be written"
    assert File.exist?(json), "crash .json should be written"
    body = File.read(txt)
    assert body.include?("RuntimeError: kaboom"), "exception line present"
    assert body.include?("--- backtrace ---")
    assert body.include?("--- current buffer ---")
  ensure
    File.delete(txt) if txt && File.exist?(txt)
    File.delete(json) if json && File.exist?(json)
  end

  # Each snapshot field is collected independently; a raising collector must
  # not abort the report — it records a placeholder instead.
  def test_add_degrades_gracefully
    info = {}
    Vimamsa::CrashHandler.add(info, "boom") { raise "nope" }
    assert info["boom"].to_s.start_with?("<unavailable"), info["boom"].inspect
    Vimamsa::CrashHandler.add(info, "ok") { 42 }
    assert_eq 42, info["ok"]
  end

  # The report captures live editor state (current buffer contents).
  def test_report_includes_buffer_state
    vma.buf.set_content("crashy #ff0000 buffer\n")
    base = Vimamsa::CrashHandler.report("test")
    body = File.read("#{base}.txt")
    assert body.include?("crashy #ff0000 buffer"), "buffer head should be captured"
  ensure
    ["#{base}.txt", "#{base}.json"].each { |f| File.delete(f) if base && File.exist?(f) }
  end
end

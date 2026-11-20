
module Vimamsa
class Action
  attr_accessor :id, :method_name, :method, :opt

  def initialize(id, method_name, method, opt = {})
    @method_name = method_name
    @id = id
    @method = method
    @opt = opt
  end
end

# Action ids are dotted paths, "move.word.next", from general to specific
# (doc/action_names_plan.md). Older ids are symbols (:close_current_buffer).
ACTION_ID_RE = /\A[a-z][a-z0-9_]*(\.[a-z0-9_]+)+\z/

# Old id => new dotted id. ActionList, bindkey, unbindkey and macros resolve
# these, so users' custom.rb and saved macros keep working. Keep each alias
# for at least two releases.
ACTION_ALIASES = {
  # Duplicates merged (2026-11-20)
  undo: "undo.last", edit_undo: "undo.last",
  redo: "undo.redo", edit_redo: "undo.redo",
  jump_last_edit: "jump.edit.prev", jump_to_last_edit: "jump.edit.prev",
  move_backward_char: "move.char.prev", e_move_backward_char: "move.char.prev",
  e_move_forward_char: "move.char.next",
  move_next_line: "move.line.next", forward_line: "move.line.next",
  move_prev_line: "move.line.prev", backward_line: "move.line.prev",
  grep_buffer: "grep.buf", invoke_grep_search: "grep.buf",
  # app namespace (2026-11-20)
  quit: "app.quit",
  restart_editor: "app.restart",
  show_settings: "app.settings",
  reload_customrb: "app.customrb.reload",
  edit_customrb: "app.customrb.edit",
  install_demo_files: "app.demo",
  # mode namespace (2026-11-20)
  insert_mode: "mode.insert",
  start_visual_mode: "mode.visual",
  prev_mode: "mode.prev",
  start_cmd_line: "mode.cmdline",
  notepad_escape: "mode.notepad.escape",
  start_browse_mode: "mode.browse",
  exit_browse_mode: "mode.browse.exit",
  toggle_kbd_passthrough: "mode.passthrough.toggle",
  minibuffer_end: "mode.minibuffer.end",
  # help namespace (2026-11-20)
  show_key_bindings: "help.keys",
  show_free_key_bindings: "help.keys.free",
  show_vim_binding_conflicts: "help.vim_conflicts",
  show_message_history: "help.messages",
  # debug namespace (2026-11-20)
  enable_debug: "debug.on",
  disable_debug: "debug.off",
  savedebug: "debug.save",
  eval_buf: "debug.eval.buf",
  experimental_eval: "debug.eval.sel",
  command_to_buf: "debug.command",
  debug_buf_hex: "debug.buf.sha256",
  print_buffer_access_list: "debug.buf.access",
  run_tests: "debug.tests",
  kbd_dump_state: "debug.kbd",
  # move namespace (2026-11-20)
  jump_beginning_of_line: "move.line.start",
  jump_end_of_line: "move.line.end",
  jump_next_word_start: "move.word.next",
  jump_prev_word_start: "move.word.prev",
  jump_next_word_end: "move.word.end",
  jump_start_of_buffer: "move.buf.start",
  jump_to_start_of_buffer: "move.buf.start",
  jump_end_of_buffer: "move.buf.end",
  jump_to_end_of_buffer: "move.buf.end",
  jump_to_random: "move.random",
  page_down: "move.page.next",
  page_up: "move.page.prev",
  # jump namespace (2026-11-20)
  jump_to_next_edit: "jump.edit.next",
  easy_jump: "jump.easy",
  open_file_under_cursor: "jump.file",
  line_action: "jump.line",
  # search namespace (2026-11-20)
  find_in_buffer: "search.buf",
  find_next: "search.next",
  gui_search_replace: "search.replace",
  invoke_replace: "search.replace.cmd",
  search_actions: "search.actions",
  # grep namespace (2026-11-20)
  grep_refresh: "grep.refresh",
  ack_search: "ack.search",
  content_search: "grep.files",
  # edit namespace (2026-11-20)
  delete_char_forward: "edit.delete.char",
  vim_delete_char: "edit.delete.char.inline",
  vim_delete_char_backward: "edit.delete.char.prev",
  vim_delete_to_eol: "edit.delete.eol",
  delete_to_word_end: "edit.delete.word.end",
  delete_to_next_word_start: "edit.delete.word.next",
  delete_to_line_start: "edit.delete.line.start",
  delete_line: "edit.delete.line",
  insert_backspace: "edit.backspace",
  insert_delete: "edit.delete.char_or_sel",
  vim_change_line: "edit.change.line",
  vim_change_word: "edit.change.word",
  vim_change_to_eol: "edit.change.eol",
  vim_substitute_char: "edit.change.char",
  vim_open_line_above: "edit.line.above",
  insert_new_line: "edit.newline",
  copy_cur_line: "edit.line.copy",
  paste_after_cursor: "edit.paste.after",
  paste_before_cursor: "edit.paste.before",
  paste_over_after: "edit.paste.over.after",
  paste_over_before: "edit.paste.over.before",
  increment_word: "edit.word.increment",
  auto_indent_buffer: "edit.indent.buf",
  comment_selection: "edit.comment",
  autocp_manual_trigger: "edit.complete",
  toggle_autocomplete: "edit.complete.toggle",
  # undo namespace (2026-11-20)
  vim_repeat_last_action: "undo.repeat",
  # case namespace (2026-11-20)
  word_upcase: "case.word.upper",
  word_downcase: "case.word.lower",
  word_swapcase: "case.word.swap",
  line_upcase: "case.line.upper",
  line_downcase: "case.line.lower",
  line_swapcase: "case.line.swap",
  selection_upcase: "case.sel.upper",
  selection_downcase: "case.sel.lower",
  selection_swapcase: "case.sel.swap",
  selection_capitalize: "case.sel.capitalize",
  vim_toggle_case: "case.char.toggle",
  # sel namespace (2026-11-20)
  select_all: "sel.all",
  insert_select_up: "sel.line.prev",
  insert_select_down: "sel.line.next",
  copy_selection: "sel.copy",
  cut_selection: "sel.cut",
  vim_change_selection: "sel.change",
  selection_reverse: "sel.reverse",
  selection_remove_indent: "sel.unindent",
  selection_remove_common_indent: "sel.unindent.common",
  V_join_lines: "sel.join",
  V_to_latex_itemize: "sel.latex_itemize",
  delete_selection: "sel.delete",
  delete_append_selection: "sel.delete.append",
  # buf namespace (2026-11-20)
  buf_save: "buf.save",
  buf_save_as: "buf.save.as",
  buf_revert: "buf.revert",
  buf_backup: "buf.backup",
  backup_all_buffers: "buf.backup.all",
  buf_new: "buf.new",
  create_new_file: "buf.new",
  close_current_buffer: "buf.close",
  gui_select_buffer: "buf.switcher",
  start_buf_manager: "buf.manager",
  history_switch_backwards: "buf.history.prev",
  history_switch_forwards: "buf.history.next",
  select_buffer_language: "buf.language",
  encrypt_file: "buf.encrypt",
  set_unencrypted: "buf.encrypt.off",
  git_diff_buffer: "buf.diff.git",
  diff_buffer: "buf.diff",
  diff_buffer_jump_to_source: "diffview.source",
  # file namespace (2026-11-20)
  git_diff_w: "file.diff.repo",
  open_file_dialog: "file.open",
  gui_file_finder: "file.finder",
  start_file_selector: "file.explorer",
  update_file_index: "file.finder.reindex",
  gui_file_history_finder: "file.history",
  fhist_remove_nonexisting: "file.history.prune",
  delete_current_file: "file.delete",
  set_executable: "file.executable",
  put_file_path_to_clipboard: "file.path.copy",
  put_file_ref_to_clipboard: "file.ref.copy",
  extract_file_links: "file.links",
}

# A reference to an action by its dotted id, built by chaining: a.move.word.next
# is the reference "move.word.next" (nothing runs), and a trailing "!" runs
# it: a.buf.save!. Based on BasicObject, so ids like a.class or a.send work.
# Use a.… only in custom.rb and on the command line: in lib/, a local
# variable named "a" hides the method, so lib/ code uses the string form.
class ActionRef < BasicObject
  def initialize(path)
    @path = path
  end

  def to_s
    @path.join(".")
  end

  alias to_str to_s

  def inspect
    "a." + to_s
  end

  def respond_to?(name, _priv = false)
    [:to_s, :to_str, :inspect].include?(name)
  end

  def method_missing(name, *args)
    s = name.to_s
    # Conversion hooks Ruby probes for (to_ary, to_hash, ...) and predicates
    # aren't path segments
    ::Kernel.raise ::NoMethodError, "undefined method '#{s}' for #{inspect}" if s.start_with?("to_") || s.end_with?("?", "=")
    if s.end_with?("!")
      id = (@path + [s.chomp("!")]).join(".")
      if !$vma.actions.include?(id)
        ::Kernel.raise ::NameError, "Unknown action #{id}#{$vma.actions.did_you_mean(id)}"
      end
      return $vma.actions.call(id)
    end
    ActionRef.new(@path + [s])
  end
end

# Root of the action references: a.move.word.next, a.buf.save!
def a
  ActionRef.new([])
end

def unreg_act(id)
  vma.actions.unregister(id)
end

# id: a dotted id string ("buf.save"), an a.… reference, or an old symbol
def reg_act(id, callfunc, name = "", opt = {})
  id = id.to_s if ActionRef === id
  if callfunc.class == Proc
    a = Action.new(id, name, callfunc, opt)
  else
    begin
      m = method(callfunc)
    rescue NameError
      m = method("missing_callfunc")
    end
    a = Action.new(id, name, m, opt)
  end
  vma.actions.register(id, a)
  return a
end

def missing_callfunc
  debug "missing_callfunc"
end

#TODO: remove?
def call_action(id)
  vma.actions.call(id)
end

class ActionList
  def initialize
    @acth = []
    @actions = {}
  end

  # The registry key for id: an a.… reference becomes its string, and an old
  # id listed in ACTION_ALIASES becomes its new id (noted once per old id).
  def resolve(id)
    id = id.to_s if ActionRef === id
    if (id.class == Symbol || id.class == String) && (new_id = ACTION_ALIASES[id.to_sym])
      @aliases_noted ||= {}
      if !@aliases_noted[id.to_sym]
        @aliases_noted[id.to_sym] = true
        message("action :#{id} is now #{new_id}")
      end
      return new_id
    end
    id
  end

  # " (did you mean x.y?)" for an unknown id, or ""
  def did_you_mean(id)
    ids = @actions.keys.select { |k| k.class == String && k.match?(ACTION_ID_RE) } +
          @actions.keys.select { |k| k.class == Symbol }.map(&:to_s)
    c = DidYouMean::SpellChecker.new(dictionary: ids).correct(id.to_s).first
    c ? " (did you mean #{c}?)" : ""
  end

  def register(id, obj)
    @actions[resolve(id)] = obj
  end

  def unregister(id)
    @actions.delete(resolve(id))
  end

  def include?(act)
    return @actions.has_key?(resolve(act))
  end

  def [](id)
    @actions[resolve(id)]
  end

  def ids
    @actions.keys
  end

  def call(id)
    id = resolve(id)
    @acth << id
    a = @actions[id]
    if a
      a.method.call()
    else
      message("Unknown action: " + id.inspect)
    end
  end

  def last_action
    return @acth[-1]
  end

  def gui_search()
    l = []
    opt = { :title => "Search for actions", :desc => "Fuzzy search for actions. <up> or <down> to change selcted. <enter> to select current.",
            :columns => [{ :title => "Shortcut", :id => 0 }, { :title => "Action", :id => 1 }] }

    @select_keys = ["h", "l", "f", "d", "s", "a", "g", "z"]

    gui_select_update_window(l, @select_keys.collect { |x| x.upcase },
                             self.method("search_actions_select_callback"),
                             self.method("search_actions_update_callback"),
                             opt)
  end

  @item_list = []

  def search_actions_update_callback(search_str = "")
    return [] if search_str == ""

    item_list2 = []
    for act_id in @actions.keys
      act = @actions[act_id]
      item = {}
      item[:key] = ""

      for mode_str in ["C", "V"]
        c_kbd = vma.kbd.act_bindings[mode_str][act_id]
        if c_kbd.class == String
          item[:key] = "[#{mode_str}] #{c_kbd} "
          item[:key] = "" if item[:key].size > 15
          break
        end
      end
      # c_kbd = vma.kbd.act_bindings[mode_str][nfo[:action]]
      item[:action] = act_id
      item[:str] = act_id.to_s
      if @actions[act_id].method_name != ""
        item[:str] = @actions[act_id].method_name
      end
      item_list2 << item
    end

    item_list = item_list2

    a = filter_items(item_list, 0, search_str)
    debug a.inspect

    r = a.collect { |x| [x[0][0], 0, x] }
    debug r.inspect
    @item_list = r

    r = a.collect { |x| [x[0][:key], x[0][:str]] }
    return r
  end

  def search_actions_select_callback(search_str, idx)
    item = @item_list[idx][2]
    acc = item[0][:action]

    debug "Selected:" + acc.to_s
    gui_select_window_close(0)

    # Dotted ids, old symbol ids and Ruby-code bindings alike
    exec_action(acc)
  end

  def filter_items(item_list, item_key, search_str)
    item_hash = {}
    # debug item_list.inspect
    scores = Parallel.map(item_list, in_threads: 8) do |item|
      if item[:str].class != String
        puts item.inspect
        exit!
      end
      [item, srn_dst(search_str, item[:str])]
    end
    scores.sort_by! { |x| -x[1] }
    debug scores.inspect
    scores = scores[0..30]

    return scores
  end
end
end # module Vimamsa

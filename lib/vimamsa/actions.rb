class Action
  attr_accessor :id, :method_name, :method, :opt

  def initialize(id, method_name, method, opt = {})
    @method_name = method_name
    @id = id
    @method = method
    @opt = opt
    vma.actions.register(id, self) # TODO: handle this in Editor class
  end
end

def reg_act(id, callfunc, name = "", opt = {})
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

  def register(id, obj)
    @actions[id] = obj
  end

  def include?(act)
    return @actions.has_key?(act)
  end

  def [](id)
    @actions[id]
  end

  def call(id)
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

    if acc.class == String
      eval(acc)
    elsif acc.class == Symbol
      debug "Symbol"
      call(acc)
    end
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

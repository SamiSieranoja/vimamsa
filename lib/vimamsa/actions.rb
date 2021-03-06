class Action
  attr_accessor :id, :method_name, :method, :opt

  def initialize(id, method_name, method, opt = {})
    @method_name = method_name
    @id = id
    @method = method
    @opt = opt

    $actions[id] = self
  end
end

$actions = {}

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
  puts "missing_callfunc"
end

#TODO: remove
def call(id)
  call_action(id)
end

def call_action(id)
  a = $actions[id]
  if a
    a.method.call()
  else
    message("Unknown action: " + id.inspect)
  end
end

def search_actions()
  l = []
  $select_keys = ["h", "l", "f", "d", "s", "a", "g", "z"]
  gui_select_update_window(l, $select_keys.collect { |x| x.upcase },
                           "search_actions_select_callback",
                           "search_actions_update_callback")
end

$item_list = []

def search_actions_update_callback(search_str = "")
  return [] if search_str == ""

  item_list2 = []
  for act_id in $actions.keys
    act = $actions[act_id]
    item = {}
    item[:key] = ""
    item[:action] = act_id
    item[:str] = act_id.to_s
    if $actions[act_id].method_name != ""
      item[:str] = $actions[act_id].method_name
    end
    item_list2 << item
  end

  item_list = item_list2

  a = filter_items(item_list, 0, search_str)
  puts a.inspect

  r = a.collect { |x| [x[0][0], 0, x] }
  puts r.inspect
  $item_list = r

  r = a.collect { |x| ["[#{x[0][:key]}] #{x[0][:str]}", 0, x] }
  return r
end

def search_actions_select_callback(search_str, idx)
  item = $item_list[idx][2]
  acc = item[0][:action]

  puts "Selected:" + acc.to_s
  gui_select_window_close(0)

  if acc.class == String
    eval(acc)
  elsif acc.class == Symbol
    puts "Symbol"
    call(acc)
  end
end

def filter_items(item_list, item_key, search_str)
  #    Ripl.start :binding => binding
  item_hash = {}
  scores = Parallel.map(item_list, in_threads: 8) do |item|
    [item, srn_dst(search_str, item[:str])]
  end
  scores.sort_by! { |x| -x[1] }
  puts scores.inspect
  scores = scores[0..30]

  return scores
end

class Action
  attr_accessor :id, :method_name, :method

  def initialize(id, method_name, method)
    @method_name = method_name
    @id = id
    @method = method
  end
end

$actions = {}

def reg_act(id, callfunc, name)
  if callfunc.class == Proc
    a = Action.new(id, name, callfunc)
  else
    a = Action.new(id, name, method(callfunc))
  end
  $actions[id] = a
end

def call(id)
  a = $actions[id]
  if a
    #        Ripl.start :binding => binding
    a.method.call()
  end
end

def search_actions()
  l = []
  $select_keys = ["h", "l", "f", "d", "s", "a", "g", "z"]
  qt_select_update_window(l, $select_keys.collect { |x| x.upcase },
                          "search_actions_select_callback",
                          "search_actions_update_callback")
end

$item_list = []

def search_actions_update_callback(search_str = "")
  #    item_list = $actions.collect {|x| x[1].id.to_s}
  return [] if search_str == ""
  item_list = $action_list.collect { |x|
    r = { :str => x[:action].to_s, :key => x[:key], :action => x[:action] }
  }

  a = filter_items(item_list, 0, search_str)
  puts a.inspect

  r = a.collect { |x| [x[0][0], 0, x] }
  puts r.inspect
  $item_list = r

  r = a.collect { |x| ["[#{x[0][:key]}] #{x[0][:str]}", 0, x] }
  return r
end

def search_actions_select_callback(search_str)
  #    Ripl.start :binding => binding
  #    acc = $item_list[0][0].to_s
  item = $item_list[0][2]
  acc = item[0][1]

  #    acc1 = $item_list[0][1]
  puts "Selected:" + acc.to_s
  if acc.class == String
    eval(acc)
  elsif acc.class == Symbol
    puts "Symbol"
    call(acc)
  end
  qt_select_window_close(0)
end

def filter_items(item_list, item_key, search_str)
  #    Ripl.start :binding => binding
  item_hash = {}
  scores = Parallel.map(item_list, in_threads: 8) do |item|
    [item, srn_dst(search_str, item[:str])]
  end
  scores.sort_by! { |x| -x[1] }
  #    Ripl.start :binding => binding
  puts scores.inspect
  scores = scores[0..30]

  return scores
end

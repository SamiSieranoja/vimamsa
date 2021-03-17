class Action
  attr_accessor :id, :method_name, :method

  def initialize(id, method_name, method, scope = [])
    @method_name = method_name
    @id = id
    @method = method
    $actions[id] = self
  end
end

$actions = {}

# def reg_act(id, callfunc, name = "", scope = [])
  # if callfunc.class == Proc
    # a = Action.new(id, name, callfunc, scope)
  # else
    # a = Action.new(id, name, method(callfunc), scope)
  # end
# end

def reg_act(id, callfunc, name = "", scope = [])
  if callfunc.class == Proc
    a = Action.new(id, name, callfunc, scope)
  else
    begin
      m = method(callfunc)
    rescue NameError
      m = method("missing_callfunc")
    end
    a = Action.new(id, name, m, scope)
  end
end

def missing_callfunc
  puts "missing_callfunc"
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
  gui_select_update_window(l, $select_keys.collect { |x| x.upcase },
                          "search_actions_select_callback",
                          "search_actions_update_callback")
end

$item_list = []

def search_actions_update_callback(search_str = "")
  #    item_list = $actions.collect {|x| x[1].id.to_s}
  return [] if search_str == ""
  # item_list = $action_list.collect { |x|
    # actname = x[:action].to_s
    # if x[:action].class == Symbol
      # mn = $actions[x[:action]].method_name
      # actname = mn if mn.size > 0
    # end
    # r = { :str => actname, :key => x[:key], :action => x[:action] }
  # }

  # => {:str=>"insert_new_line", :key=>"I return", :action=>:insert_new_line}

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
  # Ripl.start :binding => binding
  item_list = item_list2

  a = filter_items(item_list, 0, search_str)
  puts a.inspect

  r = a.collect { |x| [x[0][0], 0, x] }
  puts r.inspect
  $item_list = r
  # Ripl.start :binding => binding

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

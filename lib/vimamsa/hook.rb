
class HookItem
  attr_writer :method_name, :weight

  def initialize(hook_method, weight)
    @method_name = hook_method.to_s

    if hook_method.class == Method
      @call_func = hook_method
    elsif hook_method.class == String
      @call_func = method(hook_method)
    end
    @weight = weight
  end

  def call(x = nil)
    @call_func.call(x) if x != nil
    @call_func.call() if x == nil
  end
end

#$hook.register(:puts,"puts")
#$hook.call(:puts,"AAAA")

class Hook < Hash

  #attr_reader :pos,
  #attr_writer :call_func

  def initialize()
  end

  def register(hook_id, hook_method, weight = 0)
    self[hook_id] = [] if self[hook_id] == nil
    self[hook_id] << HookItem.new(hook_method, weight)
  end

  def call(hook_id, x = nil)
    if self[hook_id]
      self[hook_id].each { |hi|
        hi.call(x) if x != nil
        hi.call() if x == nil
      }
    end
  end
end

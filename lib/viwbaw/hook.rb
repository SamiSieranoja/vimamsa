
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
    a = Action.new(id, name, method(callfunc))
    $actions[id]=a
end

def call(id)
    a = $actions[id]
    if a
#        Ripl.start :binding => binding
        a.method.call()
    end
end

class HookItem
    attr_writer :method_name, :weight
    def initialize(method_name, weight)
        @method_name = method_name
        @call_func = method(method_name)
        @weight = weight
    end
    def call
        @call_func.call()
    end
end

class Hook < Hash

    #attr_reader :pos,
    #attr_writer :call_func

    def initialize()

    end
    def register(hook_id, method_name, weight = 0)
        self[hook_id] = [] if self[hook_id] == nil
        self[hook_id] << HookItem.new(method_name, weight)
    end
    def call(hook_id)
        if self[hook_id]
            self[hook_id].each {|hi|
                hi.call()
            }
        end
    end
end

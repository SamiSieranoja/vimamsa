module Vimamsa
  class HookItem
    attr_writer :method_name, :weight

    def initialize(hook_method, weight)
      @method_name = hook_method.to_s

      if [Proc, Method].include?(hook_method.class)
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

  # Hooks: named events that code elsewhere (modules, plugins, custom.rb) can
  # react to without the code that fires them knowing about it.
  #
  #   vma.hook.register(:file_saved, method(:on_saved))  # a Method, or the name
  #                                                      # of a method as a String
  #   vma.hook.call(:file_saved, buf)  # calls every registered method, in the
  #                                    # order registered, with buf (or with no
  #                                    # argument when none is given)
  #
  # Hooks fired today:
  #   :after_init         Editor#start, everything loaded       (no argument)
  #   :change_buffer      another buffer became current          the new Buffer
  #   :buffer_closed      a buffer was closed                    the Buffer
  #   :file_saved         a buffer was written to its file       the Buffer
  #   :insert_new_line    a newline is about to be inserted      the current line's text
  #   :visual_mode_ending visual mode ends, selection still up   the Buffer
  #   :view_content_set   a view got its buffer's text           the VSourceView
  #   :view_text_changed  the text in a view changed             the VSourceView
  #   :shutdown           the editor is quitting                 (no argument)
  #
  # There is no unregister: a module that can be disabled registers once and
  # checks a flag of its own (see modules/dictation/dictation.rb). `weight` is
  # stored but not used yet.

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
end # module Vimamsa

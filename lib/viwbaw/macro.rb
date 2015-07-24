
class Macro < Struct.new(:recording, :recorded_evals)
  def initialize()
    @recording = false
    @recorded_evals = {}
    @current_recording = []
    @current_name = nil
  end
  def start_recording(name)
      @recording = true
      @current_name = name
    @current_recording = []
  end
  def end_recording()
      if @recording == true
          @recorded_evals[@current_name] = @current_recording
          @current_name = @current_recording = nil
          @recording = false
      end
  end
  def is_recording
      return @recording
  end
  def record_action(eval_str)
      if @recording

            if eval_str == "repeat_last_action"
                @current_recording << $command_history.last
            else
                @current_recording << eval_str
            end
      end
  end
  def run_macro(name)
      m = @recorded_evals[name]
      if m.kind_of?(Array) and m.any?
        set_last_command({method: $macro.method("run_macro"), params: [name]})
          eval_str = m.join(";")
          debug(eval_str)
          eval(eval_str)
      end
  end
end


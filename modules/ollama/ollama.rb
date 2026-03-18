require "net/http"
require "json"

def ollama_improve_selection
  return unless vma.buf.visual_mode?
  r   = vma.buf.get_visual_mode_range
  txt = vma.buf[r]
  return if txt.nil? || txt.strip.empty?

  vma.buf.end_visual_mode
  message("Ollama: thinking…")

  Thread.new do
    result = ollama_request(txt)
    GLib::Idle.add do
      if result
        vma.buf.replace_range(r, result)
        vma.buf.view.handle_deltas
        message("Ollama: done")
      else
        message("Ollama: request failed — is ollama running?")
      end
      false
    end
  end
end

def ollama_request(text)
  model  = cnf.ollama.model! || "qwen3.5:0.8b"
  host   = cnf.ollama.host!  || "localhost"
  port   = cnf.ollama.port!  || 11434
  prompt = "Improve the following English text. " \
           "Return only the improved text, no explanation:\n\n#{text}"

  uri  = URI::HTTP.build(host: host, port: port, path: "/api/generate")
  body = JSON.generate(model: model, prompt: prompt, stream: false, think: false)

  http              = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = cnf.ollama.timeout! || 60
  req               = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
  req.body          = body

  resp = http.request(req)
  # require "pry";binding.pry
  return nil unless resp.is_a?(Net::HTTPSuccess)

  JSON.parse(resp.body)["response"]&.strip
rescue => e
  debug "Ollama error: #{e}"
  nil
end

def ollama_init
  reg_act(:ollama_improve_selection,
          proc { ollama_improve_selection },
          "Ollama: improve selected text")
  add_keys "ollama", { "V , o i" => :ollama_improve_selection }
end

def ollama_disable
  unreg_act(:ollama_improve_selection)
  unbindkey "V C , o i"
end

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

def ollama_improve_selection_multi(n = 3)
  return unless vma.buf.visual_mode?

  r   = vma.buf.get_visual_mode_range
  txt = vma.buf[r]
  return if txt.nil? || txt.strip.empty?

  # Find end of paragraph: first blank line after selection end, or end of buffer
  buf_str  = vma.buf.to_s
  blank    = buf_str.index(/\n[ \t]*\n/, r.last)
  para_end = blank || buf_str.rindex("\n") || buf_str.size - 1

  vma.buf.end_visual_mode
  message("Ollama: generating #{n} variants…")

  Thread.new do
    temp    = cnf.ollama.multi_temperature! || 1.2
    threads = n.times.map { Thread.new { ollama_request(txt, temperature: temp) } }
    results = threads.map(&:value)
    GLib::Idle.add do
      successful = results.compact
      if successful.any?
        block = successful.map.with_index(1) { |v, i| "#{i}. #{v}" }.join("\n")
        vma.buf.insert_txt_at(block, para_end + 1)
        vma.buf.view.handle_deltas
        message("Ollama: inserted #{successful.size} variant(s)")
      else
        message("Ollama: request failed — is ollama running?")
      end
      false
    end
  end
end

def ollama_request(text, temperature: nil)
  model  = cnf.ollama.model! || "qwen3.5:0.8b"
  host   = cnf.ollama.host!  || "localhost"
  port   = cnf.ollama.port!  || 11434
  prompt = "Improve the following English text. " \
           "Return only the improved text, no explanation:\n\n#{text}"

  uri      = URI::HTTP.build(host: host, port: port, path: "/api/generate")
  req_body = { model: model, prompt: prompt, stream: false, think: false }
  req_body[:options] = { temperature: temperature } if temperature
  body = JSON.generate(req_body)

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
  reg_act(:ollama_improve_selection_multi,
          proc { ollama_improve_selection_multi },
          "Ollama: generate N improved variants below paragraph")

  bindings = { "V , o i" => :ollama_improve_selection }
  (1..9).each { |n| bindings["V , o #{n} i"] = "ollama_improve_selection_multi(#{n})" }
  add_keys "ollama", bindings
end

def ollama_disable
  unreg_act(:ollama_improve_selection)
  unreg_act(:ollama_improve_selection_multi)
  unbindkey "V , o i"
  (1..9).each { |n| unbindkey "V , o #{n} i" }
end

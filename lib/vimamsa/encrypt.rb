require "openssl"

def decrypt_dialog(filename:, wrong_pass: false)
  callback = proc { |x| Encrypt.open(filename, x) }
  msg = ""
  msg = "\nWRONG PASSWORD!\n" if wrong_pass
  gui_one_input_action("Decrypt file \n #{filename}\n#{msg}", "Password:", "Decrypt", callback, { :hide => true })
end

class Encrypt
  def self.is_encrypted?(fn)
    debug "self.is_encrypted?(fn)", 2
    begin
      file = File.open(fn, "r")
      first_11_characters = file.read(11)
      return true if first_11_characters == "VMACRYPT001"
    rescue Errno::ENOENT
      puts "File not found: #{file_path}"
    rescue => e
      puts "An error occurred: #{e.message}"
    ensure
      file&.close
    end
    return false
  end

  def self.open(fn, password)
    debug "open_encrypted(filename,password)", 2
    encrypted = read_file("", fn)[11..-1]
    begin
      crypt = Encrypt.new(password)
      str = crypt.decrypt(encrypted)
      # debug "PASS OK!", 2
      bu = create_new_buffer(str)
      bu.init_encrypted(crypt: crypt, filename: fn, encrypted: encrypted)
    rescue OpenSSL::Cipher::CipherError => e
      # Wrong password
      decrypt_dialog(filename: fn, wrong_pass: true)
    end
  end

  def initialize(pass_phrase)
    salt = "uvgixEtU"
    @enc = OpenSSL::Cipher.new "AES-128-CBC"
    @enc.encrypt
    @enc.pkcs5_keyivgen pass_phrase, salt
    @dec = OpenSSL::Cipher.new "AES-128-CBC"
    @dec.decrypt
    @dec.pkcs5_keyivgen pass_phrase, salt
  end

  def encrypt(text)
    cipher = @enc
    encrypted = cipher.update text
    encrypted << cipher.final
    encrypted = encrypted.unpack("H*")[0].upcase
    @enc.reset
    return encrypted
  end

  def decrypt(encrypted)
    cipher = @dec
    encrypted = [encrypted].pack("H*").unpack("C*").pack("c*")
    plain = cipher.update encrypted
    plain << cipher.final
    plain.force_encoding("utf-8")
    @dec.reset
    return plain
  end
end

def encrypt_cur_buffer()
  callback = proc { |x| encrypt_cur_buffer_callback(x) }
  gui_one_input_action("Encrypt", "Password:", "Encrypt", callback, { :hide => true })
end

def encrypt_cur_buffer_callback(password, b = nil)
  vma.buf.set_encrypted(password)
end

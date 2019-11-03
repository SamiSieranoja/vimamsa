
require "openssl"

class Encrypt
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
    cipher=@enc
    encrypted = cipher.update text
    encrypted << cipher.final
    encrypted = encrypted.unpack('H*')[0].upcase
    @enc.reset
    return encrypted
  end

  def decrypt(encrypted)
    cipher=@dec
    encrypted = [encrypted].pack("H*").unpack("C*").pack("c*")
    plain = cipher.update encrypted
    plain << cipher.final
    plain.force_encoding("utf-8")
    @dec.reset
    return plain
  end
end

def decrypt_cur_buffer(password, b = nil)
  $buffer.decrypt(password)
end

def encrypt_cur_buffer()
  callback = proc{|x|encrypt_cur_buffer_callback(x)}
  gui_one_input_action("Encrypt", "Password:", "Encrypt", callback)
end

def encrypt_cur_buffer_callback(password,b=nil)
  $buffer.set_encrypted(password)
end


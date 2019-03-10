
require "openssl"

def encrypt(text, pass_phrase)
  salt = "uvgixEtU"
  cipher = OpenSSL::Cipher.new "AES-128-CBC"
  cipher.encrypt
  cipher.pkcs5_keyivgen pass_phrase, salt
  encrypted = cipher.update text
  encrypted << cipher.final
  return encrypted
end

def decrypt(encrypted, pass_phrase)
  salt = "uvgixEtU"
  cipher = OpenSSL::Cipher.new "AES-128-CBC"
  cipher.decrypt
  cipher.pkcs5_keyivgen pass_phrase, salt
  plain = cipher.update encrypted
  plain << cipher.final
  # OpenSSL::Cipher::CipherError: bad decrypt

  return plain
end


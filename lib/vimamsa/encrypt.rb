require "openssl"
require "securerandom"

module Vimamsa

def decrypt_dialog(filename:, wrong_pass: false)
  callback = proc { |x| Encrypt.open(filename, x) }
  msg = ""
  msg = "\nWRONG PASSWORD!\n" if wrong_pass
  gui_one_input_action("Decrypt file \n #{filename}\n#{msg}", "Password:", "Decrypt", callback, { :hide => true })
end

class Encrypt
  HEADER_V1 = "VMACRYPT001"
  HEADER_V2 = "VMACRYPT002"

  PBKDF2_ITERATIONS = 600_000
  PBKDF2_KEY_LEN    = 32   # 256-bit key for AES-256
  SALT_LEN          = 16
  NONCE_LEN         = 12
  TAG_LEN           = 16

  def self.is_encrypted?(fn)
    debug "self.is_encrypted?(fn)", 2
    begin
      file = File.open(fn, "r")
      header = file.read(11)
      return true if header == HEADER_V1 || header == HEADER_V2
    rescue Errno::ENOENT
      puts "File not found: #{fn}"
    rescue => e
      puts "An error occurred: #{e.message}"
    ensure
      file&.close
    end
    false
  end

  def self.open(fn, password)
    debug "open_encrypted(filename,password)", 2
    content = read_file("", fn)
    header  = content[0..10]
    payload = content[11..-1]
    begin
      crypt = Encrypt.new(password)
      str = (header == HEADER_V1) ? crypt.decrypt_v1(payload) : crypt.decrypt_v2(payload)
      bu = create_new_buffer(str)
      bu.init_encrypted(crypt: crypt, filename: fn, encrypted: payload)
    rescue OpenSSL::Cipher::CipherError => e
      decrypt_dialog(filename: fn, wrong_pass: true)
    end
  end

  def initialize(pass_phrase)
    @pass_phrase = pass_phrase
    # Lazy-init legacy cipher only when needed for V1 decryption
    @dec_v1 = nil
  end

  # Always produces V2 (AES-256-GCM) output. Returns uppercase hex payload.
  def encrypt(text)
    salt  = SecureRandom.random_bytes(SALT_LEN)
    nonce = SecureRandom.random_bytes(NONCE_LEN)
    key   = derive_key(salt)

    cipher = OpenSSL::Cipher.new("AES-256-GCM")
    cipher.encrypt
    cipher.key = key
    cipher.iv  = nonce

    ciphertext = cipher.update(text.b) + cipher.final
    tag = cipher.auth_tag(TAG_LEN)

    (salt + nonce + tag + ciphertext).unpack1("H*").upcase
  end

  # Decrypt a V1 (AES-128-CBC, pkcs5_keyivgen) hex payload.
  def decrypt_v1(hex_payload)
    @dec_v1 ||= begin
      c = OpenSSL::Cipher.new("AES-128-CBC")
      c.decrypt
      c.pkcs5_keyivgen(@pass_phrase, "uvgixEtU")
      c
    end
    raw   = [hex_payload.strip].pack("H*")
    plain = @dec_v1.update(raw) + @dec_v1.final
    @dec_v1.reset
    plain.force_encoding("utf-8")
  end

  # Decrypt a V2 (AES-256-GCM, PBKDF2) hex payload.
  # Raises OpenSSL::Cipher::CipherError on wrong password or tampered data.
  def decrypt_v2(hex_payload)
    raw = [hex_payload.strip].pack("H*")

    offset     = 0
    salt       = raw[offset, SALT_LEN];  offset += SALT_LEN
    nonce      = raw[offset, NONCE_LEN]; offset += NONCE_LEN
    tag        = raw[offset, TAG_LEN];   offset += TAG_LEN
    ciphertext = raw[offset..-1]

    key    = derive_key(salt)
    cipher = OpenSSL::Cipher.new("AES-256-GCM")
    cipher.decrypt
    cipher.key      = key
    cipher.iv       = nonce
    cipher.auth_tag = tag

    plain = cipher.update(ciphertext) + cipher.final
    plain.force_encoding("utf-8")
  end

  private

  def derive_key(salt)
    OpenSSL::PKCS5.pbkdf2_hmac(@pass_phrase, salt, PBKDF2_ITERATIONS, PBKDF2_KEY_LEN, "SHA256")
  end
end

def encrypt_cur_buffer()
  callback = proc { |x| encrypt_cur_buffer_callback(x) }
  gui_one_input_action("Encrypt", "Password:", "Encrypt", callback, { :hide => true })
end

def encrypt_cur_buffer_callback(password, b = nil)
  vma.buf.set_encrypted(password)
end
end # module Vimamsa

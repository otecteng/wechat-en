require "base64"
require "openssl"
require 'digest/sha1'

module WeechatClientEnAes
  def pad text
    text_length = text.length
    amount_to_pad = 32 - (text_length % 32)
    amount_to_pad = 32 if amount_to_pad == 0
    pad = amount_to_pad
    text + amount_to_pad.chr * amount_to_pad
  end

  def encode message,timestamp,nonce,from=nil,prefix='2aab967d2fff18c6'
    msg = (prefix.bytes + [message.bytes.length].pack('N').bytes + "#{message}#{from}".bytes).pack('c*')
    msg = pad(msg)
    key = @aeskey
    key = Base64.decode64(key)
    cipher = OpenSSL::Cipher::Cipher
    aes = cipher.new('aes-256-cbc').encrypt
    aes.padding = 0
    aes.key = key
    aes.iv = key[0..15]
    ret = aes.update(msg) + aes.final
    msg = Base64.encode64(ret)
    msg.gsub!("\n","")
    [msg,sign(@token,timestamp,nonce,msg)]
  end

  def decode echostr,timestamp,nonce,msg_signature=nil
    key = @aeskey
    sign(@token,timestamp,nonce,echostr)
    cipher = OpenSSL::Cipher::Cipher
    aes = cipher.new('aes-256-cbc').decrypt
    aes.padding = 0
    key = Base64.decode64 key
    msg = Base64.decode64 echostr
    aes.key = key
    aes.iv = key[0..15]
    result = aes.update msg + aes.final
    length = result[16,4].unpack('N').first
    result[20,length].force_encoding('utf-8')
  end

  def sign(token,timestamp,nonce,msg_encrypt)
    Digest::SHA1.hexdigest([token,timestamp,nonce,msg_encrypt].sort.join)
  end

end


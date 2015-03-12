# encoding: utf-8
class WechatesController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def index
    client = WeechatClientEn.new(Setting[:aeskey],Setting[:token])
    result = client.decode(params[:echostr],params[:timestamp],params[:nonce],params[:msg_signature])
    render :text=>result
  end

  def test
    @timestamp,@nonce = Time.now.to_i.to_s,"1234"
    @msg_encrypt,@msg_signature = "a","b"
    render :text,:formats => :xml
  end

  def create
    @timestamp,@nonce = Time.now.to_i.to_s,"1234"

    client = WeechatClientEn.new(Setting[:aeskey],Setting[:token])
    result = client.decode(params[:xml][:Encrypt],params[:timestamp],params[:nonce],params[:msg_signature])    
    @msg_encrypt,@msg_signature = client.pong(result,@timestamp,@nonce)
    
    render :text,:formats => :xml
  end
end
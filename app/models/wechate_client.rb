require 'faraday'
require "base64"
require "openssl"
require 'digest/sha1'
require 'nokogiri'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

class WechateClient
  
  include WechateClientHttp
  include WechateClientAes

  def initialize aeskey,token,appid=nil,secret=nil
    @host_api = 'https://qyapi.weixin.qq.com'
    @aeskey = aeskey
    @token = token
    @appid = appid
    @secret = secret
    @access_token = nil

    @urls = {
        :user_info  => "/cgi-bin/user/info",
        :menu       => "/cgi-bin/menu/create",
        :menu_get   => "/cgi-bin/menu/get",
        :user_list  => "/cgi-bin/user/get",
        :group_list => "/cgi-bin/groups/get",
        :user_change_group => "/cgi-bin/groups/members/update",
        :send => "/cgi-bin/message/custom/send",
        :media => "/cgi-bin/media/get",
        :message_send => "/cgi-bin/message/send",
        :token => "/cgi-bin/gettoken",
        :department_list => "/cgi-bin/department/list",
    }
    
  end

  def department_list
    data = api_get(:department_list)
    data["department"]
  end

  def download_media media_id
    get_api_token
    cmd = "wget 'http://file.api.weixin.qq.com/cgi-bin/media/get?access_token=#{@access_token}&media_id=#{media_id}' -O '#{Rails.root}/public/downloads/#{media_id}.jpg'"
    system(cmd)
    system("chmod +wrx '#{Rails.root}/public/downloads/#{media_id}.jpg'")
  end

  def api_get_user_list(next_openid=nil)
    args = {}
    args = {next_openid:next_openid} if next_openid
    data = api_get(:user_list,args)
    return nil unless data
    data["data"]["openid"]
  end

  def ping message,users=nil,group=nil
      params = {"touser"=> users ? users.join('|') : "@all","agentid"=>"1","safe"=>"0"}
      case message
      when String
        params["msgtype"] = "text" 
        params["text"] = {        
          "content"=> message
        }
      when File
        params["msgtype"] = "text" 
        params["file"] = {
          "media_id"=> "MEDIA_ID"
        }    
      when Array
        params["msgtype"] = "news"
        params["news"] = {
           "articles"=>message
        }
      end
      
      api_post(:message_send,params.to_json.gsub(/\\u([0-9a-z]{4})/) {|s| [$1.to_i(16)].pack("U")})      
  end

  def pong message,timestamp,nonce
      xml = Nokogiri::XML(message)
      fromUserName = xml.xpath("//FromUserName").text
      toUserName = xml.xpath("//ToUserName").text
      timestamp = Time.now.to_i.to_s
      response = get_response(xml)
      msg_encrypt = case response
      when String
        build_text(fromUserName,toUserName,timestamp,response)
      when Array
        build_news(fromUserName,toUserName,timestamp,response)
      when URI
        build_image(fromUserName,toUserName,timestamp,response)
      end
      encode(msg_encrypt,timestamp,nonce,toUserName)
  end

  def get_response xml
    Rails.logger.info "===============>>"
    Rails.logger.info xml
    Rails.logger.info "===============<<"
    msg_type = xml.xpath("//MsgType").text
    fromUserName = xml.xpath("//FromUserName").text
    ret = case msg_type
    when "image"
      image_callback(xml.xpath("//PicUrl").text)
    when msg_type=="event"
      event = xml.xpath("//Event").text
      event_key = xml.xpath("//EventKey").text
      ret = case event 
      when "click"
        event_callback(event,event_key)
      when "scancode_waitmsg"
        "" # event_callback(event,event_key,xml.xpath("//ScanResult").text)
      when "location_select"
        ""
      end
    end
  end

  def build_text fromUserName,toUserName,timestamp,response
    "<xml><ToUserName><![CDATA[#{fromUserName}]]></ToUserName><FromUserName><![CDATA[#{toUserName}]]></FromUserName><CreateTime>#{timestamp}</CreateTime><MsgType><![CDATA[text]]></MsgType><Content><![CDATA[#{response}]]></Content></xml>"
  end

  def build_image fromUserName,toUserName,timestamp,response
    "<xml><ToUserName><![CDATA[toUser]]></ToUserName><FromUserName><![CDATA[fromUser]]></FromUserName><CreateTime>12345678</CreateTime><MsgType><![CDATA[news]]></MsgType><ArticleCount>2</ArticleCount><Articles><item><Title><![CDATA[title1]]></Title> <Description><![CDATA[description1]]></Description><PicUrl><![CDATA[picurl]]></PicUrl><Url><![CDATA[url]]></Url></item></Articles></xml>"
  end

  def build_news fromUserName,toUserName,timestamp,response
    items = response.map do |item|
      "<item><Title><![CDATA[#{item.title}]]></Title><Description><![CDATA[#{item.description}]]></Description><PicUrl><![CDATA[#{item.picurl}]]></PicUrl><Url><![CDATA[#{item.url}]]></Url></item>"
    end.join

    "<xml><ToUserName><![CDATA[#{fromUserName}]]></ToUserName><FromUserName><![CDATA[#{toUserName}]]></FromUserName><CreateTime>#{timestamp}</CreateTime><MsgType><![CDATA[news]]></MsgType><ArticleCount>#{response.length}</ArticleCount><Articles>#{items}</Articles></xml>"
  end

end


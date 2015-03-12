require 'faraday'
require "openssl"

module WechateClientHttp
  def api_get(url,args={})
    get_api_token unless @access_token
    url = "#{@urls[url]}?"
    args.each{|k,v| url = url + "&#{k.to_s}=#{v.to_s}"}
    
    if !@access_token then
      get_api_token
      return nil unless @access_token
    end
    
    conn = Faraday.new(:url =>@host_api) 
    req = url + "&access_token=#{@access_token}"
    response = conn.get req
    ret = JSON.parse(response.body)
    if ret["errcode"]!=0 then #expired
      if "42001"==ret["errcode"] then
        return nil unless get_api_token
        response = conn.get url + "&access_token=#{@access_token}"
      else
        return nil
      end
    end
    return ret
  end

  def api_post(url,body)
    get_api_token unless @access_token
    conn = Faraday.new(:url => @host_api)
    response = conn.post "#{@urls[url]}?access_token=#{@access_token}" do |req|
      req.body = body
    end
    return response
  end

  def get_api_token
    conn = Faraday.new(:url =>@host_api)
    response = conn.get "/cgi-bin/gettoken" do |req|
      req.params['corpid'] = @appid
      req.params['corpsecret'] = @secret
    end
    @access_token = JSON.parse(response.body)["access_token"]
  end
end


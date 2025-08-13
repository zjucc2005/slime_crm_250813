# frozen_string_literal： true
module Utils
  class Winnerlook
    HOST = 'https://101.37.133.245:11008'
    PLATFORM = 'voice'
    VERSION = '1.0.0'
    APP_ID = '177943'
    TOKEN = '9fb05dee02b54bd88dda819982b4abb1'

    class << self
      # Utils::Winnerlook.two_way_call('主叫', '被叫')
      def two_way_call(caller_number, callee_number)
        get_auth
        url = "#{HOST}/#{PLATFORM}/#{VERSION}/twoWay/call/#{APP_ID}/#{@sig}"
        params = {
          callerNumber: caller_number,
          calleeNumber: callee_number
        }
        res = Api.post(url, params, {}, { token: @authorization, ssl_verify_none: true })
        JSON.parse(res.body)
      end

      # 主叫号码添加白名单
      # 1. 获取短信验证码
      # Utils::Winnerlook.two_way_whitelist_getVcode('主叫')
      def two_way_whitelist_getVcode(caller_number)
        get_auth
        url = "#{HOST}/#{PLATFORM}/#{VERSION}/twoWay/whitelist/getVcode/#{APP_ID}/#{@sig}"
        params = {
          callerNumber: caller_number
        }
        res = Api.post(url, params, {}, { token: @authorization, ssl_verify_none: true })
        JSON.parse(res.body)
      end

      # 2. 验证短信验证码
      # Utils::Winnerlook.two_way_whitelist_getVcode('主叫', '短信验证码')
      def two_way_whitelist_checkVcode(caller_number, vcode)
        get_auth
        url = "#{HOST}/#{PLATFORM}/#{VERSION}/twoWay/whitelist/checkVcode/#{APP_ID}/#{@sig}"
        params = {
          callerNumber: caller_number,
          vcode: vcode
        }
        res = Api.post(url, params, {}, { token: @authorization, ssl_verify_none: true })
        JSON.parse(res.body)
      end

      def get_auth
        timestamp = Time.now.to_i * 1000                                   # unix时间戳，精确到毫秒，例：1502261073000，时间戳有效时间为5分钟
        @sig = Digest::MD5.hexdigest("#{APP_ID}#{TOKEN}#{timestamp}")      # 验证信息，sig= md5(appId+token+时间戳) ，不含+号
        @authorization = Base64.urlsafe_encode64("#{APP_ID}:#{timestamp}") # 包头验证信息，Authorization= Base64(appId:时间戳)，英文冒号
      end

    end

  end
end
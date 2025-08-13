module Utils
  class Cis3

    # CIS_BASE_URL = 'https://itest.263.net' # test
    CIS_BASE_URL = 'https://i.263.net'  # production
    USERNAME = 'lisa.zheng@hci-consulting.com'
    PASSWORD = 'crx5mx8q'
    HEADERS  = { 'content-type': 'application/json' }

    class << self

      def login
        url = "#{CIS_BASE_URL}/rest/server/login"
        params = {
            loginName: USERNAME,
            pwd: PASSWORD,
            callBackUrl: '',
            type: 'user',
            isVersion: '1.0.0'
        }
        res = Api.post(url, params, HEADERS)
        res  # return
      end

    end

  end
end
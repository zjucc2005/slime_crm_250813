# encoding: utf-8
require 'net/http'

module Utils
  class Api

    ##
    # http methods for api
    #
    def self.get(url, params={}, headers={}, options={})
      self.http_request('get', url, params, headers, options)
    end

    def self.post(url, params={}, headers={}, options={})
      self.http_request('post', url, params, headers, options)
    end

    def self.put(url, params={}, headers={}, options={})
      self.http_request('put', url, params, headers, options)
    end

    def self.delete(url, params={}, headers={}, options={})
      self.http_request('delete', url, params, headers, options)
    end

    # @param cert_pem_file [String] 自签名ssl证书
    def self.http_request(method, url, params={}, headers={}, options={})
      uri = URI.parse(url)
      http = ::Net::HTTP.new(uri.host, uri.port)
      if url.start_with? 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if options[:ssl_verify_none]
      end
      request = case method.upcase
                  when 'GET'    then ::Net::HTTP::Get.new(uri.request_uri)
                  when 'POST'   then ::Net::HTTP::Post.new(uri.request_uri)
                  when 'PUT'    then ::Net::HTTP::Put.new(uri.request_uri)
                  when 'DELETE' then ::Net::HTTP::Delete.new(uri.request_uri)
                  else raise NoMethodError
                end
      headers.each{ |key, value| request["#{key}"] = "#{value}" }
      case method.upcase
        when 'GET'    then request.set_form_data(params)
        when 'POST'   then request.body = JSON.dump params
        when 'PUT'    then request.body = JSON.dump params
        when 'DELETE' then request.set_form_data(params)
        else raise NoMethodError
      end
      if options[:set_form_data]
        request.set_form_data(params)
      end

      Rails.logger.info("CALL: url[#{url}]")
      unless Rails.env.production?
        Rails.logger.info("body => #{request.body}")
        request.each do |r_key,r_value|
          Rails.logger.info("#{r_key} => #{r_value}")
        end
      end

      request.add_field 'authorization', options[:token] if options[:token]
      http.request(request)
    end

  end
end


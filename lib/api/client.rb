require 'httpx'
require 'json'

module Telegem
  module API
    class Client
      BASE_URL = 'https://api.telegram.org'
      
      attr_reader :token, :logger, :http

      def initialize(token, **options)
        @token = token
        @mutex = Mutex.new
        @logger = options[:logger] || Logger.new($stdout)
        timeout = options[:timeout] || 30
        
        @http = HTTPX.plugin(:callbacks).with(
          timeout: { 
            request_timeout: timeout,
            connect_timeout: 10,
            write_timeout: 10,
            read_timeout: timeout
          },
          headers: {
            'Content-Type' => 'application/json',
            'User-Agent' => "Telegem/#{Telegem::VERSION}"
          }
        )
      end
        def call(method, params = {}) 
          url = "#{BASE_URL}/bot#{@token}/#{method}"
          @logger.debug("Api call #{method}") if @logger 
          response = @http.post(url, json: params.compact)
          json = response.json 
          if json && json['ok'] 
            json['result'] 
          else 
            raise APIError.new(json ? json['description']: "Api Error")
           end  
         end  
        def call!(method, params = {}, &callback)
  url = "#{BASE_URL}/bot#{@token}/#{method}"
  
  if callback
    @http.on_response_completed do |request, response|
      begin
        if response.status == 200
          json = response.json
          if json && json['ok']
            callback.call(json['result'], nil)
            @logger.debug("API Response: #{json}") if @logger
          else
            error_msg = json ? json['description'] : "No JSON response"
            error_code = json['error_code'] if json
            callback.call(nil, APIError.new("API Error: #{error_msg}", error_code))
          end
        else
          callback.call(nil, NetworkError.new("HTTP #{response.status}"))
        end
      rescue JSON::ParserError
        callback.call(nil, NetworkError.new("Invalid JSON response"))
      rescue => e
        callback.call(nil, e)
      end
    end
    
    @http.on_request_error do |request, error|
      callback.call(nil, error)
    end
  end

  @http.post(url, json: params.compact)
  
end
      def upload(method, params)
        url = "#{BASE_URL}/bot#{@token}/#{method}"
        
        form = params.map do |key, value|
          if file_object?(value)
            [key.to_s, HTTPX::FormData::File.new(value)]
          else
            [key.to_s, value.to_s]
          end
        end
         response = @http.post(url, form: form).await
         response.json 
      end

      def get_updates(offset: nil, timeout: 30, limit: 100, allowed_updates: nil)
        params = { timeout: timeout, limit: limit }
        params[:offset] = offset if offset
        params[:allowed_updates] = allowed_updates if allowed_updates
        call('getUpdates', params)
      end

      def close
        @http.close
      end

      private

      def file_object?(obj)
        obj.is_a?(File) || obj.is_a?(StringIO) || obj.is_a?(Tempfile) ||
          (obj.is_a?(String) && File.exist?(obj))
      end
    end

    class APIError < StandardError
      attr_reader :code
      
      def initialize(message, code = nil)
        super(message)
        @code = code
      end
    end

    class NetworkError < APIError; end
  end
end
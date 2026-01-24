require 'httpx'
require 'json'
require 'httpx/plugins/form_data'

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
           return unless callback
             @http.post(url, json: params.compact) do |response| 
                begin 
                  if response.status == 200
                    json = response.json 
                     if json && json['ok'] 
                       @logger.debug("#{json}") if @logger 
                       callback.call(json['result'], nil) 
                      else 
                        error_msg = json ? 
                        json['description'] : "NO JSON Response" 
                        error_code = json['error_code'] if json 
                        callback.call(nil, APIError.new("API ERROR  #{error_msg}", error_code))
                      end 
                  else
                    callback.call(nil, NetworkError.new("HTTP #{response.status}")) 
                  end 
                rescue JSON::ParserError
                  callback.call(nil, NetworkError.new("Invalid Json response"))
                rescue => e
                  callback.call(nil, e)
                end 
              end 
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
         response = @http.post(url, form: form)
         response.json 
      end
      
      def download(file_id, destination_path = nil) 
         file_info = call('getFile', file_id: file_id)
         return nil unless file_info && file_info['file_path'] 
         file_path = file_info['file_path'] 
         download_url = "#{BASE_URL}/file/bot#{@token}/#{file_path}"
         @logger.debug("downloading.. #{download_url}") if @logger 
         response = @http.get(download_url)
         if response.status == 200
           if destination_path
             File.binwrite(destination_path, response.body.to_s)
             @logger.debug("saved to #{destination_path}") if @logger 
             destination_path
           else 
             response.body.to_s 
           end 
         else 
           raise NetworkError.new("Download failed : #{response.status}") 
         end 
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
# frozen_string_literal: true

require "openai/chat/version"
require "net/http"
require "uri"
require "json"

module OpenAI
  class Chat
    attr_accessor :messages, :schema, :model

    def initialize(api_token: nil)
      @api_token = api_token || ENV.fetch("OPENAI_TOKEN")
      @messages = []
      @model = "gpt-4o"
    end

    def system(content)
      messages.push({role: "system", content: content})
    end

    def user(content)
      messages.push({role: "user", content: content})
    end

    def assistant(content)
      messages.push({role: "assistant", content: content})
    end

    def assistant!
      request_headers_hash = {
        "Authorization" => "Bearer #{@api_token}",
        "content-type" => "application/json",
      }

      response_format = if schema.nil?
        {
          "type" => "text"
        }
      else
        {
          "type" => "json_schema",
          "json_schema" => JSON.parse(schema)
        }
      end

      request_body_hash = {
        "model" => model,
        "response_format" => response_format,
        "messages" => messages
      }

      request_body_json = JSON.generate(request_body_hash)

      uri = URI("https://api.openai.com/v1/chat/completions")
      raw_response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Post.new(uri, request_headers_hash)
        request.body = request_body_json
        http.request(request)
      end

      parsed_response = JSON.parse(raw_response.body)

      content = parsed_response.fetch("choices").at(0).fetch("message").fetch("content")

      messages.push({role: "assistant", content: content})

      schema.nil? ? content : JSON.parse(content)
    end

    def inspect
      "#<#{self.class.name} @messages=#{messages.inspect} @model=#{@model.inspect} @schema=#{@schema.inspect}>"
    end
  end
end

# frozen_string_literal: true

require "openai/chat/version"

module OpenAI
  class Chat
    require "active_support/core_ext/object/blank"
    require "http"
    require "json"
  
    attr_accessor :messages, :schema, :model
  
    def initialize(api_token: nil)
      @api_token = api_token || ENV.fetch("OPENAI_TOKEN")
      @messages = []
      @model = "gpt-4o"
    end
  
    def system(content)
      messages.push({role: "system", content:})
    end
  
    def user(content)
      messages.push({role: "user", content:})
    end

    def assistant(content)
      messages.push({role: "assistant", content:})
    end

    def assistant!
      request_headers_hash = {
        "Authorization" => "Bearer #{@api_token}",
        "content-type" => "application/json",
      }
  
      response_format = if schema.present?
        {
          "type" => "json_schema",
          "json_schema" => JSON.parse(schema)
        }
      else
        {
          "type" => "text"
        }
      end
  
      request_body_hash = {
        "model" => model,
        "response_format" => response_format,
        "messages" => messages
      }
  
      request_body_json = JSON.generate(request_body_hash)
  
      raw_response = HTTP.headers(request_headers_hash).post(
        "https://api.openai.com/v1/chat/completions",
        :body => request_body_json,
      ).to_s
  
      parsed_response = JSON.parse(raw_response)
  
      content = parsed_response.fetch("choices").at(0).fetch("message").fetch("content")
  
      messages.push({role: "assistant", content:})
  
      schema.present? ? JSON.parse(content) : content
    end
  end
end

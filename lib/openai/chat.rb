# frozen_string_literal: true

require "base64"
require "json"
require "mime/types"
require "net/http"
require "openai/chat/version"
require "pathname"
require "uri"

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

    def user(content, image: nil, images: nil)
      if (image.nil? && images.nil?) || content.is_a?(Array)
        messages.push(
          {
            role: "user",
            content: content
          }
        )
      else
        text_and_images_array = [
          {
            type: "text",
            text: content
          }
        ]

        if images.present?
          images_array = images.map do |image|
            {
              type: "image_url",
              image_url: {
                url: process_image(image)
              }
            }
          end

          text_and_images_array += images_array
        else
          text_and_images_array.push(
            {
              type: "image_url",
              image_url: {
                url: process_image(image)
              }
            }
          )
        end

        messages.push(
          {
            role: "user",
            content: text_and_images_array
          }
        )
      end
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

    private

    # Custom exception class for input classification errors.
    class InputClassificationError < StandardError; end

    def classify_obj(obj)
      if obj.is_a?(String)
        # Attempt to parse as a URL.
        begin
          uri = URI.parse(obj)
          if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
            return :url
          end
        rescue URI::InvalidURIError
          # Not a valid URL; continue to check if it's a file path.
        end

        # Check if the string represents a local file path (must exist on disk).
        if File.exist?(obj)
          return :file_path
        else
          raise InputClassificationError,
                "String provided is neither a valid URL (must start with http:// or https://) nor an existing file path on disk. Received value: #{obj.inspect}"
        end
      else
        # For non-String objects, check if it behaves like a file.
        if obj.respond_to?(:read)
          return :file_like
        else
          raise InputClassificationError,
                "Object provided is neither a String nor file-like (missing :read method). Received value: #{obj.inspect}"
        end
      end
    end

    def process_image(obj)
      case classify_obj(obj)
      when :url
        image
      when :file_path
        file_path = obj

        mime_type = MIME::Types.type_for(file_path).first.to_s

        image_data = File.binread(file_path)

        base64_string = Base64.strict_encode64(image_data)

        "data:#{mime_type};base64,#{base64_string}"
      when :file_like
        filename = obj

        mime_type = MIME::Types.type_for(filename).first.to_s

        base64_string = Base64.strict_encode64(image_data)

        data_uri = "data:#{mime_type};base64,#{base64_string}"
      end
    end
  end
end

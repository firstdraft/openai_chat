# frozen_string_literal: true

FactoryBot.define do
  factory :chat, class: OpenAI::Chat do
    api_token { "dummy_token" }

    initialize_with { new(api_token: api_token) }
  end
end

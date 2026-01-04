# frozen_string_literal: true

FactoryBot.define do
  factory :conversation do
    session_id { SecureRandom.uuid }
    status { 'active' }
    metadata { {} }
    user { nil }

    trait :with_user do
      association :user
    end

    trait :closed do
      status { 'closed' }
    end

    trait :archived do
      status { 'archived' }
    end

    trait :with_messages do
      after(:create) do |conversation|
        create(:conversation_message, conversation: conversation, role: 'user', content: 'Hello')
        create(:conversation_message, conversation: conversation, role: 'assistant', content: 'How can I help?')
      end
    end
  end
end

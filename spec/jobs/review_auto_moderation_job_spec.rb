# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewAutoModerationJob, type: :job do
  let(:client) { create(:client) }
  let(:service_point) { create(:service_point) }
  let(:review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 5,
           comment: 'Great tire service!',
           status: 'pending',
           moderation_status: 'pending',
           skip_notifications: true)
  end

  before do
    AiRequestWrapper.reset!
    Rails.cache.clear
  end

  after do
    AiRequestWrapper.reset!
  end

  describe '#perform' do
    context 'when review exists and is pending' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'classification' => 'positive',
                'sentiment' => 'positive',
                'confidence' => 0.95,
                'is_fake' => false,
                'fake_indicators' => [],
                'topics' => ['quality'],
                'summary' => 'Positive review'
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'moderates the review' do
        described_class.new.perform(review.id)

        review.reload
        expect(review.moderation_status).to eq('approved')
        expect(review.ai_classification).to eq('positive')
      end

      it 'generates suggested reply for approved reviews' do
        reply_response = {
          'choices' => [{
            'message' => {
              'content' => '{"reply": "Thank you!", "tone": "appreciative"}'
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(
          {
            'choices' => [{
              'message' => {
                'content' => {
                  'classification' => 'positive',
                  'sentiment' => 'positive',
                  'confidence' => 0.95,
                  'is_fake' => false,
                  'fake_indicators' => [],
                  'topics' => [],
                  'summary' => 'Positive'
                }.to_json
              }
            }]
          },
          reply_response
        )

        described_class.new.perform(review.id)

        review.reload
        expect(review.ai_suggested_reply).to be_present
      end
    end

    context 'when review does not exist' do
      it 'does not raise an error' do
        expect { described_class.new.perform(999_999) }.not_to raise_error
      end
    end

    context 'when review is already moderated' do
      it 'skips moderation' do
        review.update(moderation_status: 'approved', skip_notifications: true)

        expect_any_instance_of(ReviewModerationService).not_to receive(:moderate)
        described_class.new.perform(review.id)
      end
    end
  end

  describe 'enqueueing' do
    it 'enqueues to the default queue' do
      expect {
        described_class.perform_later(review.id)
      }.to have_enqueued_job(described_class)
        .with(review.id)
        .on_queue('default')
    end
  end
end

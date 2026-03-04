# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewModerationService, type: :service do
  let(:service) { described_class.new }

  # Build a mock review object for testing
  let(:client) { create(:client) }
  let(:service_point) { create(:service_point) }

  let(:positive_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 5,
           comment: 'Great service! Fast tire change and friendly staff.',
           status: 'pending',
           skip_notifications: true)
  end

  let(:negative_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 1,
           comment: 'Terrible experience. Waited 3 hours and they scratched my rims.',
           status: 'pending',
           skip_notifications: true)
  end

  let(:neutral_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 3,
           comment: 'Normal service, nothing special. Price was okay.',
           status: 'pending',
           skip_notifications: true)
  end

  let(:spam_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 5,
           comment: 'Buy cheap tires at http://spam-site.com discount 50%!!!',
           status: 'pending',
           skip_notifications: true)
  end

  let(:profanity_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 1,
           comment: 'These idiots are complete garbage',
           status: 'pending',
           skip_notifications: true)
  end

  before do
    AiRequestWrapper.reset!
    Rails.cache.clear
  end

  after do
    AiRequestWrapper.reset!
  end

  describe '#moderate' do
    context 'with spam content (quick filter)' do
      it 'rejects reviews with promotional links' do
        result = service.moderate(spam_review)

        expect(result[:status]).to eq('rejected')
        expect(result[:classification]).to eq('spam')
        expect(result[:reason]).to eq('spam_detected')
        expect(result[:confidence]).to be >= 0.9
      end

      it 'flags reviews with repeated characters' do
        review = create(:review,
                        client: client,
                        service_point: service_point,
                        rating: 5,
                        comment: 'aaaaaaaaaaaaa',
                        status: 'pending',
                        skip_notifications: true)

        result = service.moderate(review)
        expect(result[:status]).to eq('rejected')
        expect(result[:reason]).to eq('spam_detected')
      end

      it 'flags reviews with contact information' do
        review = create(:review,
                        client: client,
                        service_point: service_point,
                        rating: 4,
                        comment: 'Good service! Call me at +380501234567 for more.',
                        status: 'pending',
                        skip_notifications: true)

        result = service.moderate(review)
        expect(result[:status]).to eq('flagged')
        expect(result[:reason]).to eq('contact_info_detected')
      end
    end

    context 'with AI moderation' do
      let(:ai_success_response) do
        {
          'choices' => [{
            'message' => {
              'content' => {
                'classification' => 'positive',
                'sentiment' => 'positive',
                'confidence' => 0.95,
                'is_fake' => false,
                'fake_indicators' => [],
                'topics' => ['service_speed', 'staff'],
                'summary' => 'Positive review about fast service and friendly staff'
              }.to_json
            }
          }]
        }
      end

      before do
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(ai_success_response)
      end

      it 'auto-approves positive reviews with high confidence' do
        result = service.moderate(positive_review)

        expect(result[:status]).to eq('approved')
        expect(result[:classification]).to eq('positive')
        expect(result[:confidence]).to be >= 0.8
        expect(result[:reason]).to eq('auto_approved_high_confidence')
      end

      it 'updates review moderation fields' do
        service.moderate(positive_review)

        positive_review.reload
        expect(positive_review.moderation_status).to eq('approved')
        expect(positive_review.ai_classification).to eq('positive')
        expect(positive_review.ai_sentiment).to eq('positive')
        expect(positive_review.moderated_at).to be_present
      end

      it 'auto-publishes approved reviews' do
        service.moderate(positive_review)

        positive_review.reload
        expect(positive_review.status).to eq('published')
      end
    end

    context 'with negative review AI response' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'classification' => 'negative',
                'sentiment' => 'negative',
                'confidence' => 0.9,
                'is_fake' => false,
                'fake_indicators' => [],
                'topics' => ['wait_time', 'damage'],
                'summary' => 'Negative review about long wait and rim damage'
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'approves negative reviews with high confidence and alerts partner' do
        result = service.moderate(negative_review)

        expect(result[:status]).to eq('approved')
        expect(result[:classification]).to eq('negative')
        expect(result[:reason]).to eq('negative_approved_alert_partner')
        expect(result[:alert_partner]).to be true
      end
    end

    context 'with suspected fake review' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'classification' => 'positive',
                'sentiment' => 'positive',
                'confidence' => 0.85,
                'is_fake' => true,
                'fake_indicators' => ['overly_generic', 'marketing_language'],
                'topics' => [],
                'summary' => 'Suspected fake review'
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'flags suspected fake reviews for manual moderation' do
        result = service.moderate(positive_review)

        expect(result[:status]).to eq('flagged')
        expect(result[:reason]).to eq('suspected_fake_review')
        expect(result[:is_fake]).to be true
      end
    end

    context 'with low confidence AI response' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'classification' => 'neutral',
                'sentiment' => 'neutral',
                'confidence' => 0.4,
                'is_fake' => false,
                'fake_indicators' => [],
                'topics' => [],
                'summary' => 'Unclear review'
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'flags reviews with low confidence for manual review' do
        result = service.moderate(neutral_review)

        expect(result[:status]).to eq('flagged')
        expect(result[:reason]).to eq('low_confidence')
      end
    end

    context 'when AI is unavailable' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:chat_completion)
          .and_raise(Timeout::Error, 'connection timed out')
        allow(AiRequestWrapper).to receive(:sleep) # Speed up retries in tests
      end

      it 'falls back to flagged status for manual review' do
        result = service.moderate(positive_review)

        expect(result[:status]).to eq('flagged')
        expect(result[:reason]).to eq('ai_unavailable')
        expect(result[:confidence]).to eq(0.0)
      end
    end

    context 'with caching' do
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
                'topics' => [],
                'summary' => 'Test'
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'returns cached result on second call' do
        first_result = service.moderate(positive_review)
        second_result = service.moderate(positive_review)

        expect(first_result).to eq(second_result)
      end
    end
  end

  describe '#analyze_sentiment' do
    context 'when AI is available' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'sentiment' => 'positive',
                'pros' => ['fast service', 'friendly staff'],
                'cons' => [],
                'topics' => ['speed', 'staff']
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'returns sentiment analysis' do
        result = service.analyze_sentiment(positive_review)

        expect(result[:sentiment]).to eq('positive')
        expect(result[:review_id]).to eq(positive_review.id)
        expect(result[:pros]).to be_an(Array)
      end
    end

    context 'when AI is unavailable' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:chat_completion)
          .and_raise(StandardError, 'API error')
        allow(AiRequestWrapper).to receive(:sleep)
      end

      it 'falls back to rating-based sentiment' do
        result = service.analyze_sentiment(positive_review)

        expect(result[:sentiment]).to eq('positive')
        expect(result[:review_id]).to eq(positive_review.id)
      end
    end
  end

  describe '#batch_moderate' do
    before do
      response = {
        'choices' => [{
          'message' => {
            'content' => {
              'classification' => 'positive',
              'sentiment' => 'positive',
              'confidence' => 0.9,
              'is_fake' => false,
              'fake_indicators' => [],
              'topics' => [],
              'summary' => 'Test'
            }.to_json
          }
        }]
      }
      allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
    end

    it 'moderates multiple reviews' do
      results = service.batch_moderate([positive_review, neutral_review])

      expect(results).to be_an(Array)
      expect(results.length).to eq(2)
    end
  end
end

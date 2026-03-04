# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewReplyGeneratorService, type: :service do
  let(:service) { described_class.new }

  let(:client) { create(:client) }
  let(:service_point) { create(:service_point) }

  let(:positive_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 5,
           comment: 'Excellent service! Changed all 4 tires in 30 minutes. Very professional.',
           status: 'published',
           ai_sentiment: 'positive',
           ai_classification: 'positive',
           skip_notifications: true)
  end

  let(:negative_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 1,
           comment: 'Waited 2 hours. They scratched my alloy wheels. Terrible experience.',
           status: 'published',
           ai_sentiment: 'negative',
           ai_classification: 'negative',
           skip_notifications: true)
  end

  let(:neutral_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 3,
           comment: 'Normal service. Nothing special but okay.',
           status: 'published',
           ai_sentiment: 'neutral',
           ai_classification: 'neutral',
           skip_notifications: true)
  end

  let(:spam_review) do
    create(:review,
           client: client,
           service_point: service_point,
           rating: 5,
           comment: 'Buy tires cheap',
           status: 'rejected',
           ai_classification: 'spam',
           moderation_status: 'rejected',
           skip_notifications: true)
  end

  before do
    AiRequestWrapper.reset!
    Rails.cache.clear
  end

  after do
    AiRequestWrapper.reset!
  end

  describe '#generate' do
    context 'for positive reviews with AI available' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'reply' => 'Spasibo za otzyv! We are glad you appreciated the speed of service.',
                'tone' => 'appreciative'
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'generates appreciative reply for positive reviews' do
        result = service.generate(positive_review)

        expect(result[:suggested_reply]).to be_present
        expect(result[:tone]).to eq('appreciative')
        expect(result[:sentiment]).to eq('positive')
        expect(result[:generated_at]).to be_present
      end
    end

    context 'for negative reviews with AI available' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'reply' => 'We sincerely apologize for your experience. Please contact our manager to resolve this.',
                'tone' => 'apologetic'
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'generates apologetic reply for negative reviews' do
        result = service.generate(negative_review)

        expect(result[:suggested_reply]).to be_present
        expect(result[:tone]).to eq('apologetic')
        expect(result[:sentiment]).to eq('negative')
      end
    end

    context 'for neutral reviews with AI available' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'reply' => 'Thank you for your feedback. We hope to see you again!',
                'tone' => 'neutral'
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'generates neutral reply' do
        result = service.generate(neutral_review)

        expect(result[:suggested_reply]).to be_present
        expect(result[:sentiment]).to eq('neutral')
      end
    end

    context 'for spam/inappropriate reviews' do
      it 'skips reply generation' do
        result = service.generate(spam_review)

        expect(result[:suggested_reply]).to be_nil
        expect(result[:skipped]).to be true
        expect(result[:reason]).to eq('reply_not_applicable')
      end
    end

    context 'for reviews with empty comment' do
      it 'skips reply generation' do
        review = create(:review,
                        client: client,
                        service_point: service_point,
                        rating: 5,
                        comment: '',
                        status: 'published',
                        skip_notifications: true)

        result = service.generate(review)
        expect(result[:skipped]).to be true
      end
    end

    context 'when AI is unavailable' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:chat_completion)
          .and_raise(Timeout::Error, 'timeout')
        allow(AiRequestWrapper).to receive(:sleep)
      end

      it 'returns fallback reply based on sentiment' do
        result = service.generate(positive_review)

        expect(result[:suggested_reply]).to be_present
        expect(result[:sentiment]).to eq('positive')
      end

      it 'returns Russian fallback by default' do
        result = service.generate(positive_review)

        expect(result[:suggested_reply]).to include('Спасибо')
      end
    end

    context 'with Ukrainian language option' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:chat_completion)
          .and_raise(Timeout::Error, 'timeout')
        allow(AiRequestWrapper).to receive(:sleep)
      end

      it 'returns Ukrainian fallback when language is uk' do
        result = service.generate(positive_review, language: 'uk')

        expect(result[:suggested_reply]).to include('Дякуємо')
      end
    end

    context 'with caching' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => '{"reply": "Test reply", "tone": "neutral"}'
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'caches the result' do
        first_result = service.generate(neutral_review)
        second_result = service.generate(neutral_review)

        expect(first_result).to eq(second_result)
      end
    end

    context 'with fallback to ReviewReplyTemplate' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:chat_completion)
          .and_raise(Timeout::Error, 'timeout')
        allow(AiRequestWrapper).to receive(:sleep)

        create(:review_reply_template,
               name: 'Positive reply',
               content: 'Thank you {client_name}! We appreciate your feedback.',
               category: 'positive',
               partner: service_point.partner,
               is_active: true)
      end

      it 'uses template as fallback when AI fails' do
        result = service.generate(positive_review)

        expect(result[:from_template]).to be true
        expect(result[:suggested_reply]).to be_present
      end
    end
  end

  describe '#batch_generate' do
    before do
      response = {
        'choices' => [{
          'message' => {
            'content' => '{"reply": "Thank you!", "tone": "appreciative"}'
          }
        }]
      }
      allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
    end

    it 'generates replies for multiple reviews' do
      results = service.batch_generate([positive_review, neutral_review])

      expect(results).to be_an(Array)
      expect(results.length).to eq(2)
      expect(results.first[:review_id]).to eq(positive_review.id)
    end
  end
end

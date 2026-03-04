# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeeklyForecastJob, type: :job do
  before do
    AiRequestWrapper.reset!
    Rails.cache.clear
  end

  after do
    AiRequestWrapper.reset!
  end

  describe '#perform' do
    let!(:active_partner) do
      partner = create(:partner)
      partner.user.update(is_active: true)
      create(:service_point, partner: partner)
      partner
    end

    before do
      # Stub AI calls
      allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(nil)
    end

    it 'generates forecasts for active partners' do
      expect_any_instance_of(ForecastService).to receive(:call).and_call_original

      described_class.new.perform
    end

    it 'handles errors gracefully for individual partners' do
      allow_any_instance_of(ForecastService).to receive(:call)
        .and_raise(StandardError, 'test error')

      expect { described_class.new.perform }.not_to raise_error
    end

    it 'enqueues to the default queue' do
      expect {
        described_class.perform_later
      }.to have_enqueued_job(described_class)
        .on_queue('default')
    end
  end
end

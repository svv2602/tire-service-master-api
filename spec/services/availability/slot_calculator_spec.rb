# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Availability::SlotCalculator, type: :service do
  let(:service_point) { instance_double('ServicePoint', id: 1) }
  let(:schedule_resolver) { instance_double(Availability::ScheduleResolver) }

  subject(:calculator) { described_class.new(service_point, schedule_resolver: schedule_resolver) }

  describe '#all_slots_for_date' do
    context 'when no working posts' do
      before do
        allow(schedule_resolver).to receive(:has_any_working_posts?).and_return(false)
      end

      it 'returns empty array' do
        expect(calculator.all_slots_for_date(Date.today)).to eq([])
      end
    end
  end

  describe '#available_slots_for_date' do
    before do
      allow(schedule_resolver).to receive(:has_any_working_posts?).and_return(false)
    end

    it 'filters only available slots' do
      result = calculator.available_slots_for_date(Date.today)
      expect(result).to eq([])
    end
  end

  describe '#find_next_available_time' do
    before do
      allow(schedule_resolver).to receive(:has_any_working_posts?).and_return(false)
    end

    it 'returns nil when no available slots' do
      result = calculator.find_next_available_time(Date.today)
      expect(result).to be_nil
    end
  end

  describe 'MIN_TIME_INTERVAL' do
    it 'is 15 minutes' do
      expect(described_class::MIN_TIME_INTERVAL).to eq(15)
    end
  end
end

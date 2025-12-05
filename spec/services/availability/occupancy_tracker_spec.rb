# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Availability::OccupancyTracker, type: :service do
  let(:service_point) { instance_double('ServicePoint', id: 1, service_posts: service_posts) }
  let(:service_posts) { double('service_posts', active: [], where: []) }
  let(:schedule_resolver) { instance_double(Availability::ScheduleResolver) }
  let(:slot_calculator) { instance_double(Availability::SlotCalculator) }

  subject(:tracker) do
    described_class.new(service_point,
                        schedule_resolver: schedule_resolver,
                        slot_calculator: slot_calculator)
  end

  describe '#day_occupancy_details' do
    context 'when service point not working' do
      before do
        allow(schedule_resolver).to receive(:has_any_working_posts?).and_return(false)
      end

      it 'returns not working response' do
        result = tracker.day_occupancy_details(Date.today)

        expect(result[:is_working]).to be false
        expect(result[:message]).to include('не работает')
      end
    end
  end

  describe '#day_occupancy_details_for_category' do
    context 'when category not working' do
      before do
        allow(schedule_resolver).to receive(:has_working_posts_for_category?).and_return(false)
      end

      it 'returns not working response with category' do
        result = tracker.day_occupancy_details_for_category(Date.today, 1)

        expect(result[:is_working]).to be false
        expect(result[:category_id]).to eq(1)
      end
    end
  end

  describe '#check_availability_at_time' do
    context 'when not working day' do
      before do
        allow(schedule_resolver).to receive(:has_any_working_posts?).and_return(false)
      end

      it 'returns not available' do
        result = tracker.check_availability_at_time(Date.today, '10:00')

        expect(result[:available]).to be false
        expect(result[:reason]).to eq('Не рабочий день')
      end
    end
  end

  describe 'MIN_TIME_INTERVAL' do
    it 'is 15 minutes' do
      expect(described_class::MIN_TIME_INTERVAL).to eq(15)
    end
  end
end

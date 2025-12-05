# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Availability::Service, type: :service do
  let(:service_point) { instance_double('ServicePoint', id: 1, service_posts: service_posts) }
  let(:service_posts) { double('service_posts', active: [], where: []) }

  before do
    allow(ServicePoint).to receive(:find).with(1).and_return(service_point)
  end

  subject(:service) { described_class.new(service_point) }

  describe '#initialize' do
    it 'creates schedule_resolver' do
      expect(service.schedule_resolver).to be_a(Availability::ScheduleResolver)
    end

    it 'creates slot_calculator' do
      expect(service.slot_calculator).to be_a(Availability::SlotCalculator)
    end

    it 'creates occupancy_tracker' do
      expect(service.occupancy_tracker).to be_a(Availability::OccupancyTracker)
    end

    it 'accepts service_point_id as integer' do
      service = described_class.new(1)
      expect(service.service_point).to eq(service_point)
    end
  end

  describe 'delegation methods' do
    it 'delegates all_slots_for_date to slot_calculator' do
      expect(service.slot_calculator).to receive(:all_slots_for_date).with(Date.today)
      service.all_slots_for_date(Date.today)
    end

    it 'delegates day_occupancy_details to occupancy_tracker' do
      expect(service.occupancy_tracker).to receive(:day_occupancy_details).with(Date.today)
      service.day_occupancy_details(Date.today)
    end

    it 'delegates schedule_for_date to schedule_resolver' do
      expect(service.schedule_resolver).to receive(:schedule_for_date).with(Date.today)
      service.schedule_for_date(Date.today)
    end
  end

  describe 'MIN_TIME_INTERVAL' do
    it 'is 15' do
      expect(described_class::MIN_TIME_INTERVAL).to eq(15)
    end
  end
end

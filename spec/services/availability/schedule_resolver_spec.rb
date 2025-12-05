# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Availability::ScheduleResolver, type: :service do
  let(:service_point) { instance_double('ServicePoint', id: 1, working_hours: working_hours, service_posts: service_posts) }
  let(:working_hours) do
    {
      'monday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
      'tuesday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
      'sunday' => { 'is_working_day' => false }
    }
  end
  let(:service_posts) { double('service_posts', where: [], active: []) }

  subject(:resolver) { described_class.new(service_point) }

  describe '#day_key_for_date' do
    it 'returns correct day key for Monday' do
      date = Date.new(2025, 12, 1) # Monday
      expect(resolver.day_key_for_date(date)).to eq('monday')
    end

    it 'returns correct day key for Sunday' do
      date = Date.new(2025, 12, 7) # Sunday
      expect(resolver.day_key_for_date(date)).to eq('sunday')
    end
  end

  describe '#schedule_for_date' do
    before do
      allow(SeasonalSchedule).to receive(:find_active_for_date).and_return(nil)
    end

    it 'returns working schedule for working day' do
      date = Date.new(2025, 12, 1) # Monday
      result = resolver.schedule_for_date(date)

      expect(result[:is_working]).to be true
      expect(result[:schedule_type]).to eq('regular')
    end

    it 'returns not working for non-working day' do
      date = Date.new(2025, 12, 7) # Sunday
      result = resolver.schedule_for_date(date)

      expect(result[:is_working]).to be false
    end
  end

  describe 'DAYS_OF_WEEK' do
    it 'contains all days' do
      expect(described_class::DAYS_OF_WEEK.values).to match_array(
        %w[sunday monday tuesday wednesday thursday friday saturday]
      )
    end
  end
end

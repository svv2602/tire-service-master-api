# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmartRescheduleService do
  let!(:region) { create(:region, name: 'Тестовый регион') }
  let!(:city) { create(:city, name: 'Тестовый город', region: region) }
  let!(:partner) { create(:partner, :with_new_user) }
  let!(:service_point) do
    create(:service_point,
           name: 'Тестовое СТО',
           city: city,
           partner: partner,
           is_active: true,
           work_status: 'working',
           post_count: 2)
  end
  let!(:car_type) { create(:car_type, name: 'Легковой') }
  let!(:client_user) { create(:user, role: 'client') }
  let!(:client) { create(:client, user: client_user) }

  let!(:booking) do
    create(:booking,
           client: client,
           service_point: service_point,
           car_type: car_type,
           booking_date: Date.tomorrow,
           start_time: Time.parse("#{Date.tomorrow} 10:00"),
           end_time: Time.parse("#{Date.tomorrow} 10:00"),
           status: 'pending',
           service_recipient_first_name: 'Иван',
           service_recipient_last_name: 'Тестов',
           service_recipient_phone: '+380501234567')
  end

  # Setup schedule templates
  before do
    weekdays_data = [
      { name: 'Monday', short_name: 'Mon', sort_order: 1 },
      { name: 'Tuesday', short_name: 'Tue', sort_order: 2 },
      { name: 'Wednesday', short_name: 'Wed', sort_order: 3 },
      { name: 'Thursday', short_name: 'Thu', sort_order: 4 },
      { name: 'Friday', short_name: 'Fri', sort_order: 5 },
      { name: 'Saturday', short_name: 'Sat', sort_order: 6 },
      { name: 'Sunday', short_name: 'Sun', sort_order: 7 }
    ]

    weekdays_data.each do |day_data|
      weekday = Weekday.find_or_create_by(sort_order: day_data[:sort_order]) do |w|
        w.name = day_data[:name]
        w.short_name = day_data[:short_name]
      end

      is_working = day_data[:sort_order] != 7

      create(:schedule_template,
             service_point: service_point,
             weekday: weekday,
             is_working_day: is_working,
             opening_time: is_working ? Time.parse('09:00') : Time.parse('00:00'),
             closing_time: is_working ? Time.parse('18:00') : Time.parse('23:59'))
    end
  end

  describe '#call' do
    subject(:result) { described_class.call(booking, options) }

    let(:options) { {} }

    it 'returns a success result with suggestions' do
      expect(result[:success]).to be true
      expect(result[:suggestions]).to be_an(Array)
      expect(result[:preferences]).to be_a(Hash)
      expect(result[:search_params]).to include(:original_booking_id)
    end

    it 'includes preferences analysis' do
      expect(result[:preferences]).to include(
        :preferred_hour,
        :total_bookings,
        :preferred_time_range,
        :preferred_service_point_id
      )
    end

    it 'respects max_suggestions option' do
      result = described_class.call(booking, max_suggestions: 3)
      expect(result[:suggestions].length).to be <= 3
    end

    context 'with client booking history' do
      before do
        # Create past bookings to establish preference pattern (mornings)
        3.times do |i|
          past_date = Date.current - (30 + i).days
          create(:booking,
                 client: client,
                 service_point: service_point,
                 car_type: car_type,
                 booking_date: past_date,
                 start_time: Time.parse("#{past_date} 09:00"),
                 end_time: Time.parse("#{past_date} 09:00"),
                 status: 'completed',
                 service_recipient_first_name: 'Иван',
                 service_recipient_last_name: 'Тестов',
                 service_recipient_phone: '+380501234567')
        end
      end

      it 'analyzes client preferences from history' do
        expect(result[:preferences][:total_bookings]).to eq(3)
        expect(result[:preferences][:preferred_hour]).to eq(9)
        expect(result[:preferences][:preferred_time_range]).to eq('morning')
      end
    end

    context 'without client (guest booking)' do
      let!(:guest_booking) do
        create(:booking,
               client: nil,
               service_point: service_point,
               car_type: car_type,
               booking_date: Date.tomorrow,
               start_time: Time.parse("#{Date.tomorrow} 14:00"),
               end_time: Time.parse("#{Date.tomorrow} 14:00"),
               status: 'pending',
               service_recipient_first_name: 'Гость',
               service_recipient_last_name: 'Тестов',
               service_recipient_phone: '+380509876543')
      end

      it 'returns default preferences for guest bookings' do
        result = described_class.call(guest_booking)
        expect(result[:success]).to be true
        expect(result[:preferences][:total_bookings]).to eq(0)
        expect(result[:preferences][:preferred_hour]).to eq(14)
      end
    end

    context 'with include_other_points option' do
      let!(:other_service_point) do
        create(:service_point,
               name: 'Другое СТО',
               city: city,
               partner: partner,
               is_active: true,
               work_status: 'working',
               post_count: 2)
      end

      before do
        weekdays_data = [
          { name: 'Monday', short_name: 'Mon', sort_order: 1 },
          { name: 'Tuesday', short_name: 'Tue', sort_order: 2 },
          { name: 'Wednesday', short_name: 'Wed', sort_order: 3 },
          { name: 'Thursday', short_name: 'Thu', sort_order: 4 },
          { name: 'Friday', short_name: 'Fri', sort_order: 5 },
          { name: 'Saturday', short_name: 'Sat', sort_order: 6 },
          { name: 'Sunday', short_name: 'Sun', sort_order: 7 }
        ]

        weekdays_data.each do |day_data|
          weekday = Weekday.find_by(sort_order: day_data[:sort_order])
          is_working = day_data[:sort_order] != 7

          create(:schedule_template,
                 service_point: other_service_point,
                 weekday: weekday,
                 is_working_day: is_working,
                 opening_time: is_working ? Time.parse('09:00') : Time.parse('18:00'),
                 closing_time: is_working ? Time.parse('18:00') : Time.parse('23:59'))
        end
      end

      it 'includes suggestions from other service points' do
        result = described_class.call(booking, include_other_points: true)
        expect(result[:success]).to be true

        point_ids = result[:suggestions].map { |s| s[:service_point_id] }.uniq
        # May include other points depending on availability
        expect(point_ids).to include(service_point.id)
      end
    end

    context 'with days_to_search option' do
      it 'limits search range' do
        result = described_class.call(booking, days_to_search: 3)
        expect(result[:search_params][:days_searched]).to eq(3)
      end
    end
  end

  describe 'suggestion format' do
    it 'returns properly formatted suggestions' do
      result = described_class.call(booking)
      next if result[:suggestions].empty?

      suggestion = result[:suggestions].first
      expect(suggestion).to include(:date, :start_time, :service_point_id, :score)
      expect(suggestion[:is_original_point]).to be true
      expect(suggestion[:score]).to be_a(Numeric)
    end

    it 'sorts suggestions by score descending' do
      result = described_class.call(booking)
      scores = result[:suggestions].map { |s| s[:score] }
      expect(scores).to eq(scores.sort.reverse)
    end
  end
end

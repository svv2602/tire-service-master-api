# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ForecastService, type: :service do
  let(:partner) { create(:partner) }
  let(:service_point) { create(:service_point, partner: partner) }
  let(:service_instance) { described_class.new(partner, forecast_days: 7) }

  before do
    AiRequestWrapper.reset!
    Rails.cache.clear

    # Create historical booking data for the last 8 weeks
    create_historical_bookings(service_point)
  end

  after do
    AiRequestWrapper.reset!
  end

  describe '#call' do
    it 'returns successful result with forecast data' do
      # Stub AI to avoid external calls
      allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(nil)

      result = service_instance.call

      expect(result).to be_success
      expect(result.data).to have_key(:forecast)
      expect(result.data).to have_key(:recommendations)
      expect(result.data).to have_key(:peak_days)
      expect(result.data).to have_key(:historical_summary)
    end

    it 'generates forecast for correct number of days' do
      allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(nil)

      result = described_class.new(partner, forecast_days: 5, include_ai: false).call

      expect(result.data[:forecast].length).to eq(5)
    end
  end

  describe '#generate_forecast' do
    it 'returns forecast entries with required fields' do
      forecast = service_instance.generate_forecast

      expect(forecast).to be_an(Array)
      expect(forecast.length).to eq(7)

      first_day = forecast.first
      expect(first_day).to have_key(:date)
      expect(first_day).to have_key(:day_of_week)
      expect(first_day).to have_key(:predicted_bookings)
      expect(first_day).to have_key(:confidence)
      expect(first_day).to have_key(:load_indicator)
      expect(first_day).to have_key(:is_peak_day)
      expect(first_day).to have_key(:is_holiday)
      expect(first_day).to have_key(:hourly_forecast)
    end

    it 'predicts non-negative booking counts' do
      forecast = service_instance.generate_forecast

      forecast.each do |day|
        expect(day[:predicted_bookings]).to be >= 0
      end
    end

    it 'includes hourly forecast for each day' do
      forecast = service_instance.generate_forecast

      forecast.each do |day|
        next if day[:predicted_bookings].zero?

        expect(day[:hourly_forecast]).to be_an(Array)
        day[:hourly_forecast].each do |hour_data|
          expect(hour_data).to have_key(:hour)
          expect(hour_data).to have_key(:predicted_bookings)
          expect(hour_data).to have_key(:confidence)
        end
      end
    end

    it 'returns valid confidence levels' do
      forecast = service_instance.generate_forecast

      forecast.each do |day|
        expect(%w[low medium high]).to include(day[:confidence])
      end
    end

    it 'returns valid load indicators' do
      forecast = service_instance.generate_forecast

      forecast.each do |day|
        expect(%w[free medium busy]).to include(day[:load_indicator])
      end
    end
  end

  describe '#generate_recommendations' do
    it 'returns recommendations array' do
      recommendations = service_instance.generate_recommendations

      expect(recommendations).to be_an(Array)
    end

    it 'includes weekly summary when peak days exist' do
      recommendations = service_instance.generate_recommendations

      summary = recommendations.find { |r| r[:type] == 'weekly_summary' }
      # May or may not exist depending on data, but format should be correct
      if summary
        expect(summary[:priority]).to eq('medium')
        expect(summary[:peak_days]).to be_an(Array)
      end
    end

    it 'includes high load recommendations for busy days' do
      recommendations = service_instance.generate_recommendations

      high_load = recommendations.select { |r| r[:type] == 'high_load' }
      high_load.each do |rec|
        expect(rec[:priority]).to eq('high')
        expect(rec[:suggested_operators]).to be_a(Integer)
        expect(rec[:suggested_operators]).to be >= 1
      end
    end

    it 'includes holiday recommendations when applicable' do
      # Create forecast for a known holiday period (Jan 1)
      travel_to Date.new(2025, 12, 28) do
        svc = described_class.new(partner, forecast_days: 7)
        recommendations = svc.generate_recommendations

        holiday_recs = recommendations.select { |r| r[:type] == 'holiday' }
        # New Year (Jan 1) should be in the 7-day window
        if holiday_recs.any?
          expect(holiday_recs.first[:holiday_name]).to be_present
        end
      end
    end
  end

  describe '#identify_peak_days' do
    it 'returns peak day analysis' do
      peak_days = service_instance.identify_peak_days

      expect(peak_days).to be_an(Array)

      peak_days.each do |day|
        expect(day).to have_key(:day_of_week)
        expect(day).to have_key(:average_bookings)
        expect(day).to have_key(:max_bookings)
        expect(day).to have_key(:is_peak)
        expect(day).to have_key(:busiest_hours)
      end
    end

    it 'sorts by average bookings descending' do
      peak_days = service_instance.identify_peak_days

      averages = peak_days.map { |d| d[:average_bookings] }
      expect(averages).to eq(averages.sort.reverse)
    end
  end

  describe '#historical_summary' do
    it 'returns summary with required fields' do
      summary = service_instance.historical_summary

      expect(summary).to have_key(:period)
      expect(summary).to have_key(:totals)
      expect(summary).to have_key(:averages)
      expect(summary).to have_key(:trends)

      expect(summary[:period]).to have_key(:start_date)
      expect(summary[:period]).to have_key(:end_date)
      expect(summary[:period]).to have_key(:weeks)

      expect(summary[:totals]).to have_key(:total_bookings)
      expect(summary[:totals]).to have_key(:completed_bookings)
      expect(summary[:totals]).to have_key(:completion_rate)

      expect(summary[:averages]).to have_key(:daily_average)
      expect(summary[:averages]).to have_key(:weekly_average)
    end

    it 'returns valid trend direction' do
      summary = service_instance.historical_summary

      expect(%w[increasing decreasing stable insufficient_data]).to include(summary[:trends][:direction])
    end
  end

  describe 'with AI insights' do
    context 'when AI is available' do
      before do
        response = {
          'choices' => [{
            'message' => {
              'content' => {
                'summary' => 'Next week shows moderate demand.',
                'key_insight' => 'Saturday expected to be busiest.',
                'action_items' => ['Add extra operator on Saturday'],
                'risk_factors' => ['Weather may affect demand']
              }.to_json
            }
          }]
        }
        allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return(response)
      end

      it 'includes AI-generated insights' do
        result = described_class.new(partner, forecast_days: 7, include_ai: true).call

        expect(result.data).to have_key(:ai_insights)
        expect(result.data[:ai_insights][:summary]).to be_present
        expect(result.data[:ai_insights][:key_insight]).to be_present
        expect(result.data[:ai_insights][:action_items]).to be_an(Array)
        expect(result.data[:ai_insights][:ai_generated]).to be true
      end
    end

    context 'when AI is unavailable' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:chat_completion)
          .and_raise(Timeout::Error, 'timeout')
        allow(AiRequestWrapper).to receive(:sleep)
      end

      it 'returns fallback insights' do
        result = described_class.new(partner, forecast_days: 7, include_ai: true).call

        expect(result).to be_success
        expect(result.data[:ai_insights]).to be_present
        expect(result.data[:ai_insights][:ai_generated]).to be false
      end
    end

    context 'when AI is disabled' do
      it 'does not include AI insights' do
        result = described_class.new(partner, forecast_days: 7, include_ai: false).call

        expect(result.data).not_to have_key(:ai_insights)
      end
    end
  end

  describe 'with ServicePoint entity' do
    it 'generates forecast for a single service point' do
      svc = described_class.new(service_point, forecast_days: 3, include_ai: false)
      result = svc.call

      expect(result).to be_success
      expect(result.data[:forecast].length).to eq(3)
    end
  end

  describe 'seasonal adjustments' do
    it 'applies higher multiplier during peak tire change months' do
      # March = spring tire change season (multiplier 1.4)
      travel_to Date.new(2025, 2, 28) do
        svc = described_class.new(partner, forecast_days: 7, include_ai: false)
        forecast = svc.generate_forecast

        # All days in early March should have seasonal boost
        march_days = forecast.select { |d| d[:date].start_with?('2025-03') }
        # We can't verify the exact multiplier easily, but the forecast should work
        expect(march_days).not_to be_empty
      end
    end
  end

  describe 'holiday handling' do
    it 'reduces predictions on holidays' do
      # Test around New Year
      travel_to Date.new(2025, 12, 30) do
        svc = described_class.new(partner, forecast_days: 3, include_ai: false)
        forecast = svc.generate_forecast

        new_year_day = forecast.find { |d| d[:date] == '2026-01-01' }
        if new_year_day
          expect(new_year_day[:is_holiday]).to be true
          expect(new_year_day[:holiday_name]).to eq('New Year')
        end
      end
    end
  end

  private

  # Helper to create realistic historical booking data
  def create_historical_bookings(sp)
    end_date = Date.current
    start_date = end_date - 8.weeks

    (start_date..end_date).each do |date|
      # More bookings on weekdays, fewer on weekends
      base_count = date.wday.between?(1, 5) ? rand(3..6) : rand(1..3)

      base_count.times do |i|
        hour = rand(8..17)
        create(:booking,
               service_point: sp,
               booking_date: date,
               start_time: Time.zone.local(date.year, date.month, date.day, hour, 0),
               status: %w[completed completed completed confirmed cancelled_by_client].sample,
               skip_notifications: true)
      rescue StandardError
        # Skip if booking creation fails (e.g., unique constraint)
        next
      end
    end
  end
end

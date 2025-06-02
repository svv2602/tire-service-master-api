require 'rails_helper'

RSpec.describe DynamicAvailabilityService, type: :service do
  # Используем build_stubbed чтобы избежать сохранения в БД пока не нужно
  let(:service_point) { create(:service_point, post_count: 3) }
  let(:service_posts) do
    3.times.map do |i|
      create(:service_post, 
        service_point: service_point,
        post_number: i + 1,
        slot_duration: 60,
        is_active: true
      )
    end
  end
  
  let(:weekday) { create(:weekday, name: 'Tuesday', sort_order: 2) }
  let(:schedule_template) do
    create(:schedule_template,
      service_point: service_point,
      weekday: weekday,
      is_working_day: true,
      opening_time: Time.parse('09:00'),
      closing_time: Time.parse('18:00')
    )
  end
  
  let(:client) { create(:client) }
  let(:car_type) { create(:car_type) }
  let(:pending_status) { create(:booking_status, name: 'pending') }
  
  let(:test_date) { Date.parse('2025-06-03') } # Tuesday
  
  # Создаем данные в before блоке чтобы избежать проблем с let!
  before do
    service_point
    service_posts
    schedule_template
  end
  
  describe '.available_times_for_date' do
    context 'рабочий день без бронирований' do
      it 'возвращает все доступные временные интервалы' do
        result = described_class.available_times_for_date(service_point.id, test_date)
        
        expect(result).not_to be_empty
        expect(result.count).to eq(36) # 9 часов * 4 интервала по 15 минут
        expect(result.first[:time]).to eq('09:00')
        expect(result.last[:time]).to eq('17:45')
        expect(result.first[:available_posts]).to eq(3)
        expect(result.first[:total_posts]).to eq(3)
      end
    end
    
    context 'нерабочий день' do
      let(:sunday_date) { Date.parse('2025-06-01') } # Sunday
      
      it 'возвращает пустой массив' do
        result = described_class.available_times_for_date(service_point.id, sunday_date)
        expect(result).to be_empty
      end
    end
    
    context 'с минимальной длительностью' do
      it 'возвращает только слоты с достаточным временем' do
        result = described_class.available_times_for_date(service_point.id, test_date, 120) # 2 часа
        
        expect(result).not_to be_empty
        # Последний доступный слот должен быть не позже 16:00 (чтобы уместить 2 часа до 18:00)
        expect(result.last[:time]).to eq('16:00')
      end
    end
  end
  
  describe '.check_availability_at_time' do
    context 'проверка в рабочие часы' do
      it 'возвращает доступность для свободного времени' do
        result = described_class.check_availability_at_time(service_point.id, test_date, '10:00', 60)
        
        expect(result[:available]).to be true
        expect(result[:total_posts]).to eq(3)
        expect(result[:occupied_posts]).to eq(0)
      end
    end
    
    context 'проверка вне рабочих часов' do
      it 'возвращает недоступность для времени до открытия' do
        result = described_class.check_availability_at_time(service_point.id, test_date, '08:00', 60)
        
        expect(result[:available]).to be false
        expect(result[:reason]).to eq('Вне рабочих часов')
      end
      
      it 'возвращает недоступность для времени после закрытия' do
        result = described_class.check_availability_at_time(service_point.id, test_date, '19:00', 60)
        
        expect(result[:available]).to be false
        expect(result[:reason]).to eq('Вне рабочих часов')
      end
    end
    
    context 'проверка времени выходящего за рабочие часы' do
      it 'возвращает недоступность если бронирование не помещается' do
        result = described_class.check_availability_at_time(service_point.id, test_date, '17:30', 60)
        
        expect(result[:available]).to be false
        expect(result[:reason]).to eq('Недостаточно времени до закрытия')
      end
    end
    
    context 'нерабочий день' do
      let(:sunday_date) { Date.parse('2025-06-01') } # Sunday
      
      it 'возвращает недоступность' do
        result = described_class.check_availability_at_time(service_point.id, sunday_date, '10:00', 60)
        
        expect(result[:available]).to be false
        expect(result[:reason]).to eq('Не рабочий день')
      end
    end
  end
  
  describe '.find_next_available_time' do
    it 'находит ближайшее доступное время в том же дне' do
      result = described_class.find_next_available_time(
        service_point.id, 
        test_date, 
        Time.parse("#{test_date} 10:00"), 
        60
      )
      
      expect(result).not_to be_nil
      expect(result[:time]).to eq('10:00')
    end
  end
  
  describe '.day_occupancy_details' do
    it 'возвращает детальную информацию о загрузке дня' do
      result = described_class.day_occupancy_details(service_point.id, test_date)
      
      expect(result[:is_working]).to be true
      expect(result[:opening_time]).to eq('09:00')
      expect(result[:closing_time]).to eq('18:00')
      expect(result[:total_posts]).to eq(3)
      expect(result[:intervals]).to be_an(Array)
      expect(result[:intervals].count).to eq(36)
      
      # Проверяем конкретные интервалы
      slot_09_00 = result[:intervals].find { |i| i[:time] == '09:00' }
      expect(slot_09_00[:occupied_posts]).to eq(0)
      expect(slot_09_00[:available_posts]).to eq(3)
      
      # Проверяем сводную статистику
      expect(result[:summary]).to include(:total_intervals, :busy_intervals, :free_intervals)
    end
    
    context 'нерабочий день' do
      let(:sunday_date) { Date.parse('2025-06-01') } # Sunday
      
      it 'возвращает информацию о нерабочем дне' do
        result = described_class.day_occupancy_details(service_point.id, sunday_date)
        
        expect(result[:is_working]).to be false
        expect(result[:intervals]).to be_nil
      end
    end
  end
  
  describe 'приватные методы' do
    describe '.get_schedule_for_date' do
      it 'возвращает рабочие часы для рабочего дня' do
        result = described_class.send(:get_schedule_for_date, service_point, test_date)
        
        expect(result[:is_working]).to be true
        expect(result[:opening_time]).to eq(schedule_template.opening_time)
        expect(result[:closing_time]).to eq(schedule_template.closing_time)
      end
      
      context 'с исключением в расписании' do
        let(:exception) do
          create(:schedule_exception,
            service_point: service_point,
            exception_date: test_date,
            is_closed: true
          )
        end
        
        it 'учитывает исключения' do
          exception # create the exception
          result = described_class.send(:get_schedule_for_date, service_point, test_date)
          
          expect(result[:is_working]).to be false
        end
      end
    end
  end
end 
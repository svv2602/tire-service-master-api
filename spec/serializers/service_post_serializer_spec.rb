require 'rails_helper'

RSpec.describe ServicePostSerializer, type: :serializer do
  let(:service_point) { create(:service_point) }
  
  describe 'сериализация без индивидуального расписания' do
    let(:service_post) { create(:service_post, service_point: service_point, has_custom_schedule: false) }
    let(:serializer) { ServicePostSerializer.new(service_post) }
    let(:serialized_data) { serializer.as_json }

    it 'включает базовые атрибуты' do
      expect(serialized_data).to include(
        :id => service_post.id,
        :post_number => service_post.post_number,
        :name => service_post.name,
        :slot_duration => service_post.slot_duration,
        :is_active => service_post.is_active,
        :description => service_post.description,
        :has_custom_schedule => false
      )
    end

    it 'включает вычисляемые атрибуты' do
      expect(serialized_data).to include(
        :display_name => service_post.display_name,
        :slot_duration_in_seconds => service_post.slot_duration_in_seconds
      )
    end

    it 'возвращает nil для полей индивидуального расписания' do
      expect(serialized_data[:working_days]).to be_nil
      expect(serialized_data[:custom_hours]).to be_nil
      expect(serialized_data[:working_days_list]).to eq([])
    end

    it 'включает данные о точке обслуживания' do
      expect(serialized_data).to have_key(:service_point)
      expect(serialized_data[:service_point]).to include(
        :id => service_point.id,
        :name => service_point.name
      )
    end
  end

  describe 'сериализация с индивидуальным расписанием' do
    let(:working_days) do
      {
        'monday' => true,
        'tuesday' => false,
        'wednesday' => true,
        'thursday' => true,
        'friday' => false,
        'saturday' => false,
        'sunday' => false
      }
    end
    
    let(:custom_hours) do
      {
        'start' => '10:00',
        'end' => '19:00'
      }
    end

    let(:service_post) do
      create(:service_post, 
        service_point: service_point,
        has_custom_schedule: true,
        working_days: working_days,
        custom_hours: custom_hours
      )
    end

    let(:serializer) { ServicePostSerializer.new(service_post) }
    let(:serialized_data) { serializer.as_json }

    it 'включает флаг индивидуального расписания' do
      expect(serialized_data[:has_custom_schedule]).to be true
    end

    it 'включает рабочие дни' do
      expect(serialized_data[:working_days]).to eq(working_days)
    end

    it 'включает индивидуальные часы' do
      expect(serialized_data[:custom_hours]).to eq(custom_hours)
    end

    it 'включает список рабочих дней' do
      expected_working_days = ['monday', 'wednesday', 'thursday']
      expect(serialized_data[:working_days_list]).to contain_exactly(*expected_working_days)
    end
  end

  describe 'сериализация поста с частичным индивидуальным расписанием' do
    let(:service_post) do
      create(:service_post, 
        service_point: service_point,
        has_custom_schedule: true,
        working_days: { 'monday' => true },
        custom_hours: nil
      )
    end

    let(:serializer) { ServicePostSerializer.new(service_post) }
    let(:serialized_data) { serializer.as_json }

    it 'возвращает nil для пустых custom_hours' do
      expect(serialized_data[:custom_hours]).to be_nil
    end

    it 'включает working_days если они заданы' do
      expect(serialized_data[:working_days]).to eq({ 'monday' => true })
    end
  end
end 
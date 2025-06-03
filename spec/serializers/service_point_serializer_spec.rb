require 'rails_helper'

RSpec.describe ServicePointSerializer, type: :serializer do
  let(:partner) { create(:partner) }
  let(:city) { create(:city) }
  let(:service_point) { create(:service_point, partner: partner, city: city, is_active: true, work_status: 'working') }
  let!(:service_posts) { create_list(:service_post, 3, service_point: service_point) }
  let!(:inactive_post) { create(:service_post, :inactive, service_point: service_point) }

  subject { described_class.new(service_point) }

  describe 'основные атрибуты' do
    it 'включает все необходимые атрибуты' do
      serialized = subject.as_json

      expect(serialized).to include(
        'id', 'name', 'description', 'address', 'latitude', 'longitude', 
        'contact_phone', 'is_active', 'work_status', 'status_display',
        'post_count', 'default_slot_duration', 'rating', 'total_clients_served',
        'average_rating', 'cancellation_rate', 'created_at', 'updated_at',
        'posts_count', 'service_posts_summary'
      )
    end

    it 'корректно сериализует базовые поля' do
      serialized = subject.as_json

      expect(serialized['id']).to eq(service_point.id)
      expect(serialized['name']).to eq(service_point.name)
      expect(serialized['is_active']).to eq(true)
      expect(serialized['work_status']).to eq('working')
    end
  end

  describe '#status_display' do
    context 'когда статус работы "working"' do
      it 'возвращает правильное отображение статуса' do
        allow(service_point).to receive(:display_status).and_return('Работает')
        serialized = subject.as_json

        expect(serialized['status_display']).to eq('Работает')
      end
    end

    context 'когда статус работы "temporarily_closed"' do
      before { service_point.update(work_status: 'temporarily_closed') }

      it 'возвращает правильное отображение статуса' do
        allow(service_point).to receive(:display_status).and_return('Временно закрыта')
        serialized = subject.as_json

        expect(serialized['status_display']).to eq('Временно закрыта')
      end
    end
  end

  describe '#posts_count' do
    it 'возвращает количество активных постов' do
      serialized = subject.as_json

      expect(serialized['posts_count']).to eq(3) # только активные посты
    end

    context 'когда нет активных постов' do
      before { service_point.service_posts.update_all(is_active: false) }

      it 'возвращает 0' do
        serialized = subject.as_json

        expect(serialized['posts_count']).to eq(0)
      end
    end
  end

  describe '#service_posts_summary' do
    it 'возвращает краткую информацию об активных постах' do
      serialized = subject.as_json
      posts_summary = serialized['service_posts_summary']

      expect(posts_summary).to be_an(Array)
      expect(posts_summary.size).to eq(3) # только активные посты

      # Проверяем структуру каждого поста
      posts_summary.each do |post_info|
        expect(post_info).to include('id', 'post_number', 'name', 'slot_duration', 'is_active')
        expect(post_info['is_active']).to be true
      end
    end

    it 'возвращает посты отсортированные по номеру' do
      # Обновляем номера постов в обратном порядке
      service_point.service_posts.active.each_with_index do |post, index|
        post.update(post_number: 10 - index)
      end

      serialized = subject.as_json
      posts_summary = serialized['service_posts_summary']
      post_numbers = posts_summary.map { |post| post['post_number'] }

      expect(post_numbers).to eq(post_numbers.sort)
    end

    it 'включает правильные данные для каждого поста' do
      serialized = subject.as_json
      posts_summary = serialized['service_posts_summary']
      first_post_summary = posts_summary.first
      first_post = service_point.service_posts.active.order(:post_number).first

      expect(first_post_summary['id']).to eq(first_post.id)
      expect(first_post_summary['post_number']).to eq(first_post.post_number)
      expect(first_post_summary['name']).to eq(first_post.name)
      expect(first_post_summary['slot_duration']).to eq(first_post.slot_duration)
      expect(first_post_summary['is_active']).to eq(first_post.is_active)
    end

    context 'когда нет активных постов' do
      before { service_point.service_posts.update_all(is_active: false) }

      it 'возвращает пустой массив' do
        serialized = subject.as_json

        expect(serialized['service_posts_summary']).to eq([])
      end
    end
  end

  describe 'связанные объекты' do
    it 'включает информацию о партнере' do
      serialized = subject.as_json

      expect(serialized).to have_key('partner')
    end

    it 'включает информацию о городе' do
      serialized = subject.as_json

      expect(serialized).to have_key('city')
    end

    it 'включает информацию о фотографиях' do
      serialized = subject.as_json

      expect(serialized).to have_key('photos')
      expect(serialized['photos']).to be_an(Array)
    end

    it 'включает информацию об удобствах' do
      serialized = subject.as_json

      expect(serialized).to have_key('amenities')
      expect(serialized['amenities']).to be_an(Array)
    end
  end

  describe 'backward compatibility' do
    it 'сохраняет поля post_count и default_slot_duration для совместимости' do
      serialized = subject.as_json

      expect(serialized).to have_key('post_count')
      expect(serialized).to have_key('default_slot_duration')
    end

    it 'не включает устаревшее поле status_id' do
      serialized = subject.as_json

      expect(serialized).not_to have_key('status_id')
    end
  end
end 
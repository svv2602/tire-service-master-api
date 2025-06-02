require 'rails_helper'

RSpec.describe ServicePost, type: :model do
  # Создаем тестовые данные
  let(:service_point) { build_stubbed(:service_point) }
  let(:service_post) { build_stubbed(:service_post, service_point: service_point) }
  
  describe 'Связи' do
    it { should belong_to(:service_point) }
  end
  
  describe 'Валидации' do
    subject { build(:service_post) }
    
    it { should validate_presence_of(:post_number) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slot_duration) }
    
    it { should validate_uniqueness_of(:post_number).scoped_to(:service_point_id) }
    it { should validate_numericality_of(:post_number).is_greater_than(0) }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_numericality_of(:slot_duration).is_greater_than(15).is_less_than_or_equal_to(480) }
    
    context 'когда номер поста уже существует в той же точке обслуживания' do
      let!(:service_point) { create(:service_point) }
      let!(:existing_post) { create(:service_post, service_point: service_point, post_number: 1) }
      
      it 'не позволяет создать пост с тем же номером' do
        duplicate_post = build(:service_post, service_point: service_point, post_number: 1)
        expect(duplicate_post).not_to be_valid
        expect(duplicate_post.errors[:post_number]).to include('Номер поста должен быть уникальным в рамках точки обслуживания')
      end
    end
    
    context 'когда номер поста существует в другой точке обслуживания' do
      let!(:service_point_1) { create(:service_point) }
      let!(:service_point_2) { create(:service_point) }
      let!(:existing_post) { create(:service_post, service_point: service_point_1, post_number: 1) }
      
      it 'позволяет создать пост с тем же номером' do
        post = build(:service_post, service_point: service_point_2, post_number: 1)
        expect(post).to be_valid
      end
    end
  end
  
  describe 'Скоупы' do
    let!(:service_point) { create(:service_point) }
    let!(:active_post) { create(:service_post, service_point: service_point, is_active: true) }
    let!(:inactive_post) { create(:service_post, service_point: service_point, is_active: false, post_number: 2) }
    
    describe '.active' do
      it 'возвращает только активные посты' do
        expect(ServicePost.active).to include(active_post)
        expect(ServicePost.active).not_to include(inactive_post)
      end
    end
    
    describe '.for_service_point' do
      let!(:another_service_point) { create(:service_point) }
      let!(:another_post) { create(:service_post, service_point: another_service_point) }
      
      it 'возвращает посты только для указанной точки обслуживания' do
        posts = ServicePost.for_service_point(service_point.id)
        expect(posts).to include(active_post, inactive_post)
        expect(posts).not_to include(another_post)
      end
    end
    
    describe '.ordered_by_post_number' do
      let!(:post_3) { create(:service_post, service_point: service_point, post_number: 3) }
      let!(:post_1) { create(:service_post, service_point: service_point, post_number: 1) }
      
      it 'возвращает посты отсортированными по номеру поста' do
        ordered_posts = ServicePost.ordered_by_post_number
        expect(ordered_posts.pluck(:post_number)).to eq([1, 2, 3])
      end
    end
  end
  
  describe 'Методы экземпляра' do
    describe '#slot_duration_in_seconds' do
      it 'возвращает длительность слота в секундах' do
        post = build(:service_post, slot_duration: 60)
        expect(post.slot_duration_in_seconds).to eq(3600)
      end
    end
    
    describe '#display_name' do
      context 'когда у поста есть имя' do
        it 'возвращает форматированное имя с номером поста' do
          post = build(:service_post, post_number: 1, name: 'Шиномонтаж')
          expect(post.display_name).to eq('Пост 1 - Шиномонтаж')
        end
      end
      
      context 'когда у поста нет имени' do
        it 'возвращает только номер поста' do
          post = build(:service_post, post_number: 2, name: '')
          expect(post.display_name).to eq('Пост 2')
        end
      end
    end
    
    describe '#available?' do
      it 'возвращает true для активного поста' do
        post = build(:service_post, is_active: true)
        expect(post.available?).to be true
      end
      
      it 'возвращает false для неактивного поста' do
        post = build(:service_post, is_active: false)
        expect(post.available?).to be false
      end
    end
    
    describe '#next_available_slot_start_time' do
      let(:service_post) { build(:service_post) }
      
      it 'возвращает переданное время (базовая реализация)' do
        time = Time.current
        expect(service_post.next_available_slot_start_time(time)).to eq(time)
      end
      
      it 'использует текущее время по умолчанию' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)
        expect(service_post.next_available_slot_start_time).to eq(freeze_time)
      end
    end
  end
end

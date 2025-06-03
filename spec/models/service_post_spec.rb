require 'rails_helper'

RSpec.describe ServicePost, type: :model do
  let(:service_point) { create(:service_point) }
  let(:service_post) { build(:service_post, service_point: service_point) }

  describe 'валидации' do
    it 'валиден с корректными атрибутами' do
      expect(service_post).to be_valid
    end

    describe 'post_number' do
      it 'обязателен' do
        service_post.post_number = nil
        expect(service_post).not_to be_valid
        expect(service_post.errors[:post_number]).to include("can't be blank")
      end

      it 'должен быть уникальным в рамках сервисной точки' do
        create(:service_post, service_point: service_point, post_number: 1)
        duplicate_post = build(:service_post, service_point: service_point, post_number: 1)
        
        expect(duplicate_post).not_to be_valid
        expect(duplicate_post.errors[:post_number]).to include('has already been taken')
      end

      it 'может быть одинаковым для разных сервисных точек' do
        another_service_point = create(:service_point)
        create(:service_post, service_point: service_point, post_number: 1)
        same_number_different_point = build(:service_post, service_point: another_service_point, post_number: 1)
        
        expect(same_number_different_point).to be_valid
      end

      it 'должен быть положительным числом' do
        service_post.post_number = 0
        expect(service_post).not_to be_valid
        expect(service_post.errors[:post_number]).to include('must be greater than 0')
        
        service_post.post_number = -1
        expect(service_post).not_to be_valid
        expect(service_post.errors[:post_number]).to include('must be greater than 0')
      end
    end

    describe 'name' do
      it 'обязательно' do
        service_post.name = nil
        expect(service_post).not_to be_valid
        expect(service_post.errors[:name]).to include("can't be blank")
      end

      it 'не может быть пустой строкой' do
        service_post.name = ''
        expect(service_post).not_to be_valid
        expect(service_post.errors[:name]).to include("can't be blank")
      end
    end

    describe 'slot_duration' do
      it 'обязательна' do
        service_post.slot_duration = nil
        expect(service_post).not_to be_valid
        expect(service_post.errors[:slot_duration]).to include("can't be blank")
      end

      it 'должна быть положительным числом' do
        service_post.slot_duration = 0
        expect(service_post).not_to be_valid
        expect(service_post.errors[:slot_duration]).to include('must be greater than 0')
        
        service_post.slot_duration = -15
        expect(service_post).not_to be_valid
        expect(service_post.errors[:slot_duration]).to include('must be greater than 0')
      end
    end

    describe 'is_active' do
      it 'по умолчанию true' do
        new_post = ServicePost.new
        expect(new_post.is_active).to be true
      end

      it 'может быть false' do
        service_post.is_active = false
        expect(service_post).to be_valid
      end
    end
  end

  describe 'связи' do
    it 'принадлежит сервисной точке' do
      expect(service_post.service_point).to eq(service_point)
    end

    it 'удаляется при удалении сервисной точки' do
      service_post.save!
      service_point_id = service_point.id
      service_point.destroy
      
      expect(ServicePost.where(service_point_id: service_point_id)).to be_empty
    end
  end

  describe 'скоупы' do
    let!(:active_post) { create(:service_post, service_point: service_point, is_active: true) }
    let!(:inactive_post) { create(:service_post, :inactive, service_point: service_point) }

    describe '.active' do
      it 'возвращает только активные посты' do
        expect(ServicePost.active).to include(active_post)
        expect(ServicePost.active).not_to include(inactive_post)
      end
    end

    describe '.ordered_by_post_number' do
      let!(:post_3) { create(:service_post, service_point: service_point, post_number: 3) }
      let!(:post_1) { create(:service_post, service_point: service_point, post_number: 1) }
      let!(:post_2) { create(:service_post, service_point: service_point, post_number: 2) }

      it 'возвращает посты отсортированные по номеру' do
        ordered_posts = ServicePost.ordered_by_post_number
        expect(ordered_posts.map(&:post_number)).to eq([1, 2, 3])
      end
    end
  end
end


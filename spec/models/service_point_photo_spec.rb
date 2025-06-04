require 'rails_helper'

RSpec.describe ServicePointPhoto, type: :model do
  describe 'валидации' do
    let(:service_point) { create(:service_point) }
    
    context 'поле file' do
      it 'требуется при создании новой фотографии' do
        photo = ServicePointPhoto.new(service_point: service_point)
        photo.valid?
        expect(photo.errors[:file]).to include("can't be blank")
      end
      
      it 'не требуется при обновлении существующей фотографии' do
        photo = create(:service_point_photo, service_point: service_point)
        photo.description = 'Обновленное описание'
        expect(photo).to be_valid
      end
    end
    
    context 'поле sort_order' do
      it 'должно быть положительным числом' do
        photo = build(:service_point_photo, service_point: service_point, sort_order: -1)
        photo.valid?
        expect(photo.errors[:sort_order]).to include('must be greater than 0')
      end
      
      it 'должно быть уникальным в рамках сервисной точки' do
        create(:service_point_photo, service_point: service_point, sort_order: 1)
        duplicate_photo = build(:service_point_photo, service_point: service_point, sort_order: 1)
        
        duplicate_photo.valid?
        expect(duplicate_photo.errors[:sort_order]).to include('has already been taken')
      end
      
      it 'может быть одинаковым для разных сервисных точек' do
        other_service_point = create(:service_point)
        create(:service_point_photo, service_point: service_point, sort_order: 1)
        other_photo = build(:service_point_photo, service_point: other_service_point, sort_order: 1)
        
        expect(other_photo).to be_valid
      end
    end
    
    context 'поле is_main' do
      it 'может быть только одной главной фотографией на сервисную точку' do
        create(:service_point_photo, service_point: service_point, is_main: true)
        duplicate_main = build(:service_point_photo, service_point: service_point, is_main: true)
        
        duplicate_main.valid?
        expect(duplicate_main.errors[:is_main]).to include('can only have one main photo per service point')
      end
      
      it 'позволяет несколько главных фотографий для разных сервисных точек' do
        other_service_point = create(:service_point)
        create(:service_point_photo, service_point: service_point, is_main: true)
        other_main = build(:service_point_photo, service_point: other_service_point, is_main: true)
        
        expect(other_main).to be_valid
      end
      
      it 'позволяет несколько не главных фотографий' do
        create(:service_point_photo, service_point: service_point, is_main: false)
        another_photo = build(:service_point_photo, service_point: service_point, is_main: false)
        
        expect(another_photo).to be_valid
      end
    end
  end
  
  describe 'ассоциации' do
    it 'принадлежит сервисной точке' do
      expect(ServicePointPhoto.reflect_on_association(:service_point).macro).to eq(:belongs_to)
    end
    
    it 'имеет прикрепленный файл' do
      photo = ServicePointPhoto.new
      expect(photo.respond_to?(:file)).to be true
    end
  end
  
  describe 'области видимости (scopes)' do
    let(:service_point) { create(:service_point) }
    
    before do
      create(:service_point_photo, service_point: service_point, is_main: true, sort_order: 1)
      create(:service_point_photo, service_point: service_point, is_main: false, sort_order: 2)
      create(:service_point_photo, service_point: service_point, is_main: false, sort_order: 3)
    end
    
    it 'возвращает главную фотографию' do
      main_photos = ServicePointPhoto.main
      expect(main_photos.count).to eq(1)
      expect(main_photos.first.is_main).to be true
    end
    
    it 'сортирует по sort_order' do
      photos = ServicePointPhoto.ordered
      expect(photos.map(&:sort_order)).to eq([1, 2, 3])
    end
  end
  
  describe 'коллбэки' do
    let(:service_point) { create(:service_point) }
    
    context 'before_validation' do
      it 'автоматически устанавливает sort_order если не задан' do
        create(:service_point_photo, service_point: service_point, sort_order: 1)
        photo = ServicePointPhoto.new(service_point: service_point)
        photo.valid?
        expect(photo.sort_order).to eq(2)
      end
    end
    
    context 'after_create' do
      it 'устанавливает is_main=true для первой фотографии если нет главной' do
        photo = create(:service_point_photo, service_point: service_point)
        expect(photo.is_main).to be true
      end
      
      it 'не устанавливает is_main=true если уже есть главная фотография' do
        create(:service_point_photo, service_point: service_point, is_main: true)
        second_photo = create(:service_point_photo, service_point: service_point)
        expect(second_photo.is_main).to be false
      end
    end
  end
  
  describe 'методы экземпляра' do
    let(:service_point) { create(:service_point) }
    let(:photo) { create(:service_point_photo, service_point: service_point) }
    
    it 'возвращает URL фотографии если файл прикреплен' do
      expect(photo.photo_url).to be_present
      expect(photo.photo_url).to include('localhost')
    end
    
    it 'возвращает nil если файл не прикреплен' do
      photo.file.purge
      expect(photo.photo_url).to be_nil
    end
  end
  
  describe 'удаление фотографий' do
    let(:service_point) { create(:service_point) }
    
    it 'удаляет прикрепленный файл при удалении записи' do
      photo = create(:service_point_photo, service_point: service_point)
      file_id = photo.file.id
      
      photo.destroy
      expect(ActiveStorage::Attachment.find_by(id: file_id)).to be_nil
    end
    
    it 'переназначает главную фотографию при удалении главной' do
      main_photo = create(:service_point_photo, service_point: service_point, is_main: true, sort_order: 1)
      second_photo = create(:service_point_photo, service_point: service_point, is_main: false, sort_order: 2)
      
      main_photo.destroy
      second_photo.reload
      expect(second_photo.is_main).to be true
    end
  end
end 
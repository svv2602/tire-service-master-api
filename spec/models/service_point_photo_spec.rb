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
    
    context 'поле is_main' do
      it 'может быть только одной главной фотографией на сервисную точку' do
        create(:service_point_photo, service_point: service_point, is_main: true)
        duplicate_main = build(:service_point_photo, service_point: service_point, is_main: true)
        
        duplicate_main.valid?
        expect(duplicate_main.errors[:is_main]).to include('может быть только одна главная фотография')
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
    
    context 'размер файла' do
      it 'не должен превышать 5MB' do
        photo = build(:service_point_photo, service_point: service_point)
        allow(photo).to receive(:file).and_return(double('attachment', 
          attached?: true, 
          content_type: 'image/jpeg', 
          byte_size: 6.megabytes
        ))
        
        photo.valid?
        expect(photo.errors[:file]).to include('размер файла не должен превышать 5MB')
      end
    end
    
    context 'тип файла' do
      it 'должен быть изображением' do
        photo = build(:service_point_photo, service_point: service_point)
        allow(photo).to receive(:file).and_return(double('attachment', 
          attached?: true, 
          content_type: 'application/pdf',
          byte_size: 1.megabyte
        ))
        
        photo.valid?
        expect(photo.errors[:file]).to include('должен быть изображением (JPEG, PNG, GIF или WebP)')
      end
    end
    
    context 'количество фотографий' do
      it 'не должно превышать 10 для одной сервисной точки' do
        # Создаем 10 фотографий
        10.times { create(:service_point_photo, service_point: service_point) }
        
        # Пытаемся создать 11-ю
        photo = build(:service_point_photo, service_point: service_point)
        photo.valid?
        expect(photo.errors[:base]).to include('превышено максимальное количество фотографий (10)')
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
      photos = ServicePointPhoto.sorted
      expect(photos.map(&:sort_order)).to eq([1, 2, 3])
    end
  end
  
  describe 'коллбэки' do
    let(:service_point) { create(:service_point) }
    
    context 'ensure_only_one_main_photo' do
      it 'убирает флаг главной фотографии у других при установке новой главной' do
        first_photo = create(:service_point_photo, service_point: service_point, is_main: true)
        second_photo = create(:service_point_photo, service_point: service_point, is_main: false)
        
        # Сохраняем, используя метод который обходит валидацию
        second_photo.is_main = true
        second_photo.save(validate: false)
        
        # Проверяем что коллбэк сработал
        first_photo.reload
        expect(first_photo.is_main).to be false
        expect(second_photo.is_main).to be true
      end
    end
  end
  
  describe 'методы экземпляра' do
    let(:service_point) { create(:service_point) }
    let(:photo) { create(:service_point_photo, service_point: service_point) }
    
    it 'имеет прикрепленный файл' do
      expect(photo.file).to be_attached
    end
    
    it 'может иметь описание' do
      photo.description = 'Тестовое описание'
      expect(photo.description).to eq('Тестовое описание')
    end
  end
  
  describe 'удаление фотографий' do
    let(:service_point) { create(:service_point) }
    
    it 'удаляет связи при удалении записи' do
      photo = create(:service_point_photo, service_point: service_point)
      photo_id = photo.id
      
      photo.destroy
      expect(ServicePointPhoto.find_by(id: photo_id)).to be_nil
    end
  end
end 
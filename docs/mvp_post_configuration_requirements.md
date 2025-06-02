# Требования к настройке индивидуальных постов обслуживания

## 🎯 Задача
Реализовать возможность настройки разной длительности слотов для каждого поста в сервисной точке.

**Пример сценария:**
- Пост 1: 30 минут на обслуживание
- Пост 2: 40 минут на обслуживание  
- Пост 3: 30 минут на обслуживание

**Результирующее расписание:**
```
9:00 — 3 поста доступны
9:30 — 2 поста (пост 1,3 освободились, пост 2 еще занят)
9:40 — 1 пост (пост 2 освободился)
10:00 — 2 поста (посты 1,3 снова доступны)
10:20 — 1 пост (пост 2 снова доступен)
11:00 — 3 поста доступны
```

## 🏗 Архитектурные изменения

### 1. Новая таблица service_posts
```sql
CREATE TABLE service_posts (
  id BIGSERIAL PRIMARY KEY,
  service_point_id BIGINT NOT NULL REFERENCES service_points(id),
  post_number INTEGER NOT NULL,
  name VARCHAR(255), -- "Пост быстрого обслуживания", "Пост диагностики"
  slot_duration INTEGER NOT NULL DEFAULT 60, -- минуты
  is_active BOOLEAN DEFAULT true,
  description TEXT,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  
  UNIQUE(service_point_id, post_number)
);
```

### 2. Обновить модель ServicePoint
```ruby
class ServicePoint < ApplicationRecord
  has_many :service_posts, dependent: :destroy
  has_many :schedule_slots, dependent: :destroy
  
  # Удалить post_count - теперь это service_posts.count
  # Удалить default_slot_duration - теперь у каждого поста свой
  
  def posts_count
    service_posts.active.count
  end
  
  def available_at_time(date, time)
    # Возвращает количество доступных постов в указанное время
    occupied_posts = schedule_slots
      .joins(:bookings)
      .where(slot_date: date)
      .where('start_time <= ? AND end_time > ?', time, time)
      .pluck(:post_number)
      
    service_posts.active.where.not(post_number: occupied_posts).count
  end
end
```

### 3. Новая модель ServicePost
```ruby
class ServicePost < ApplicationRecord
  belongs_to :service_point
  has_many :schedule_slots, foreign_key: :post_number, primary_key: :post_number
  
  validates :post_number, presence: true, 
    uniqueness: { scope: :service_point_id }
  validates :slot_duration, presence: true, 
    numericality: { greater_than: 0, less_than_or_equal_to: 480 }
  validates :name, length: { maximum: 255 }
  
  scope :active, -> { where(is_active: true) }
  scope :by_post_number, ->(number) { where(post_number: number) }
end
```

### 4. Обновить ScheduleManager
```ruby
class ScheduleManager
  # Генерация слотов с учетом индивидуальных настроек постов
  def self.generate_slots_from_template(service_point, date, template)
    delete_unused_slots(service_point.id, date)
    
    start_time = template.opening_time
    end_time = template.closing_time
    
    # Для каждого поста генерируем слоты с его индивидуальной длительностью
    service_point.service_posts.active.each do |post|
      generate_slots_for_post(service_point, date, post, start_time, end_time)
    end
  end
  
  private
  
  def self.generate_slots_for_post(service_point, date, post, start_time, end_time)
    current_time = start_time
    slot_duration = post.slot_duration
    
    while current_time + slot_duration.minutes <= end_time
      slot_end_time = current_time + slot_duration.minutes
      
      # Создаем слот только если его еще нет
      unless ScheduleSlot.exists?(
        service_point_id: service_point.id,
        slot_date: date,
        start_time: current_time,
        end_time: slot_end_time,
        post_number: post.post_number
      )
        ScheduleSlot.create!(
          service_point_id: service_point.id,
          slot_date: date,
          start_time: current_time,
          end_time: slot_end_time,
          post_number: post.post_number,
          is_available: true
        )
      end
      
      # Следующий слот для этого поста
      current_time = slot_end_time
    end
  end
end
```

## 📊 API для управления постами

### 1. CRUD операции для постов
```ruby
# app/controllers/api/v1/service_posts_controller.rb
class Api::V1::ServicePostsController < ApiController
  before_action :authenticate_request
  before_action :set_service_point
  before_action :set_service_post, only: [:show, :update, :destroy]
  
  # GET /api/v1/service_points/:service_point_id/posts
  def index
    posts = @service_point.service_posts.active.order(:post_number)
    render json: posts
  end
  
  # POST /api/v1/service_points/:service_point_id/posts
  def create
    post = @service_point.service_posts.build(service_post_params)
    
    if post.save
      render json: post, status: :created
    else
      render json: { errors: post.errors }, status: :unprocessable_entity
    end
  end
  
  # PUT /api/v1/service_points/:service_point_id/posts/:id
  def update
    if @service_post.update(service_post_params)
      # Регенерируем расписание для этого поста
      regenerate_schedule_for_post
      render json: @service_post
    else
      render json: { errors: @service_post.errors }, status: :unprocessable_entity
    end
  end
  
  private
  
  def service_post_params
    params.require(:service_post).permit(:name, :slot_duration, :description, :is_active)
  end
  
  def regenerate_schedule_for_post
    # Регенерируем расписание на ближайшие 30 дней
    start_date = Date.current
    end_date = start_date + 30.days
    
    (start_date..end_date).each do |date|
      ScheduleManager.generate_slots_for_date(@service_point.id, date)
    end
  end
end
```

### 2. API доступности с детализацией по постам
```ruby
# GET /api/v1/service_points/:id/availability/:date
def availability_by_posts
  date = Date.parse(params[:date])
  service_point = ServicePoint.find(params[:id])
  
  # Получаем все временные интервалы (по 15 минут)
  start_time = service_point.opening_time_for_date(date)
  end_time = service_point.closing_time_for_date(date)
  
  availability = []
  current_time = start_time
  
  while current_time < end_time
    available_posts = service_point.available_at_time(date, current_time)
    
    availability << {
      time: current_time.strftime('%H:%M'),
      available_posts_count: available_posts,
      details: post_details_at_time(service_point, date, current_time)
    }
    
    current_time += 15.minutes
  end
  
  render json: {
    date: date,
    service_point_id: service_point.id,
    availability: availability
  }
end

private

def post_details_at_time(service_point, date, time)
  service_point.service_posts.active.map do |post|
    slot = post.schedule_slots
      .where(slot_date: date)
      .where('start_time <= ? AND end_time > ?', time, time)
      .first
      
    {
      post_number: post.post_number,
      post_name: post.name,
      available: slot.nil? || !slot.booked?,
      slot_duration: post.slot_duration,
      next_available_at: next_available_time_for_post(post, date, time)
    }
  end
end
```

## 🔄 Миграция данных

### 1. Миграция для создания service_posts
```ruby
class CreateServicePosts < ActiveRecord::Migration[8.0]
  def up
    # Создаем таблицу
    create_table :service_posts do |t|
      t.references :service_point, null: false, foreign_key: true
      t.integer :post_number, null: false
      t.string :name
      t.integer :slot_duration, null: false, default: 60
      t.boolean :is_active, default: true
      t.text :description
      t.timestamps
    end
    
    add_index :service_posts, [:service_point_id, :post_number], unique: true
    
    # Мигрируем существующие данные
    ServicePoint.find_each do |sp|
      1.upto(sp.post_count) do |post_num|
        ServicePost.create!(
          service_point: sp,
          post_number: post_num,
          name: "Пост #{post_num}",
          slot_duration: sp.default_slot_duration || 60,
          is_active: true
        )
      end
    end
    
    # Удаляем старые колонки (осторожно!)
    # remove_column :service_points, :post_count
    # remove_column :service_points, :default_slot_duration
  end
  
  def down
    drop_table :service_posts
  end
end
```

## 📱 UI изменения

### 1. Настройка постов в админке партнера
```typescript
// Компонент настройки постов
interface ServicePost {
  id: number;
  post_number: number;
  name: string;
  slot_duration: number;
  is_active: boolean;
  description?: string;
}

const PostConfiguration: React.FC<{servicePointId: number}> = ({servicePointId}) => {
  const [posts, setPosts] = useState<ServicePost[]>([]);
  
  // Загрузка постов
  // Редактирование длительности слота
  // Добавление/удаление постов
  
  return (
    <div className="posts-configuration">
      <h3>Настройка постов обслуживания</h3>
      {posts.map(post => (
        <PostEditor 
          key={post.id} 
          post={post} 
          onChange={updatePost}
          onDelete={deletePost}
        />
      ))}
      <button onClick={addNewPost}>Добавить пост</button>
    </div>
  );
};
```

### 2. Отображение доступности с детализацией
```typescript
// Календарь с детализацией по постам
const AvailabilityCalendar: React.FC = () => {
  return (
    <div className="availability-grid">
      {timeSlots.map(timeSlot => (
        <div key={timeSlot.time} className="time-slot">
          <span className="time">{timeSlot.time}</span>
          <span className="available-posts">
            {timeSlot.available_posts_count} постов доступно
          </span>
          <div className="posts-details">
            {timeSlot.details.map(post => (
              <div 
                key={post.post_number}
                className={`post ${post.available ? 'available' : 'occupied'}`}
              >
                Пост {post.post_number} ({post.slot_duration}мин)
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
};
```

## 📊 Приоритетность реализации

### Приоритет 1 (критично):
1. **Модель ServicePost** и миграция
2. **Обновление ScheduleManager** для генерации разных слотов
3. **API CRUD для постов** 
4. **Миграция существующих данных**

### Приоритет 2 (важно):
1. **API детализированной доступности**
2. **UI настройки постов** в админке
3. **Обновление календаря бронирований**

### Приоритет 3 (улучшения):
1. Аналитика загрузки по постам
2. Оптимизация слотов
3. Автоматические рекомендации 
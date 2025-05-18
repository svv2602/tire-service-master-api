module TestFactoryHelper
  def seed_test_data
    # Create required lookup data
    create_status_lookups
    create_regions_and_cities
    create_service_categories
    create_amenities
  end

  private

  def create_status_lookups
    # Create booking statuses
    %w[pending confirmed completed canceled].each do |name|
      BookingStatus.find_or_create_by!(name: name)
    end

    # Create service point statuses
    %w[active inactive pending].each do |name|
      ServicePointStatus.find_or_create_by!(name: name)
    end

    # Create payment statuses
    %w[pending completed failed refunded].each do |name|
      PaymentStatus.find_or_create_by!(name: name)
    end

    # Create weekdays
    %w[monday tuesday wednesday thursday friday saturday sunday].each do |name|
      Weekday.find_or_create_by!(name: name)
    end
  end

  def create_regions_and_cities
    # Create regions and cities
    ['Москва', 'Санкт-Петербург', 'Московская область'].each do |region_name|
      region = Region.find_or_create_by!(name: region_name)
      
      if region.name == 'Москва'
        City.find_or_create_by!(name: 'Москва', region: region)
      elsif region.name == 'Санкт-Петербург'
        City.find_or_create_by!(name: 'Санкт-Петербург', region: region)
      else
        ['Химки', 'Мытищи', 'Одинцово', 'Красногорск'].each do |city_name|
          City.find_or_create_by!(name: city_name, region: region)
        end
      end
    end
  end

  def create_service_categories
    # Create service categories
    ['Замена шин', 'Развал-схождение', 'Балансировка', 'Ремонт шин'].each do |category_name|
      category = ServiceCategory.find_or_create_by!(name: category_name)
      
      # Create services for each category
      case category.name
      when 'Замена шин'
        ['Замена шин R13-R16', 'Замена шин R17-R19', 'Замена шин R20+'].each_with_index do |service_name, idx|
          Service.find_or_create_by!(name: service_name, description: "Снятие и установка #{service_name}", duration: (30 + idx * 15), service_category: category)
        end
      when 'Развал-схождение'
        ['Развал-схождение легковые', 'Развал-схождение кроссоверы', 'Развал-схождение внедорожники'].each_with_index do |service_name, idx|
          Service.find_or_create_by!(name: service_name, description: service_name, duration: (60 + idx * 15), service_category: category)
        end
      when 'Балансировка'
        ['Балансировка колес R13-R16', 'Балансировка колес R17-R19', 'Балансировка колес R20+'].each_with_index do |service_name, idx|
          Service.find_or_create_by!(name: service_name, description: service_name, duration: (20 + idx * 10), service_category: category)
        end
      when 'Ремонт шин'
        ['Устранение прокола', 'Ремонт бокового пореза', 'Ремонт грыжи'].each_with_index do |service_name, idx|
          Service.find_or_create_by!(name: service_name, description: service_name, duration: (30 + idx * 30), service_category: category)
        end
      end
    end
  end

  def create_amenities
    # Create amenities
    ['Wi-Fi', 'Кофе-машина', 'Детский уголок', 'Зона отдыха', 'TV', 'Кондиционер'].each do |name|
      Amenity.find_or_create_by!(name: name)
    end
  end
end

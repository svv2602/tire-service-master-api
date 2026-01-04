FactoryBot.define do
  factory :tire_order do
    user
    supplier
    status { 'draft' }
    client_name { 'Test Client' }
    client_phone { '+380501234567' }
    total_amount { 0 }

    trait :submitted do
      status { 'submitted' }
      after(:create) do |order|
        create(:tire_order_item, tire_order: order) if order.tire_order_items.empty?
        order.reload
      end
    end

    trait :confirmed do
      status { 'confirmed' }
      after(:create) do |order|
        create(:tire_order_item, tire_order: order) if order.tire_order_items.empty?
        order.reload
      end
    end

    trait :processing do
      status { 'processing' }
      after(:create) do |order|
        create(:tire_order_item, tire_order: order) if order.tire_order_items.empty?
        order.reload
      end
    end

    trait :shipped do
      status { 'shipped' }
      shipped_at { Time.current }
      tracking_number { 'UA123456789' }
      after(:create) do |order|
        create(:tire_order_item, tire_order: order) if order.tire_order_items.empty?
        order.reload
      end
    end

    trait :delivered do
      status { 'delivered' }
      shipped_at { 2.days.ago }
      delivered_at { Time.current }
      after(:create) do |order|
        create(:tire_order_item, tire_order: order) if order.tire_order_items.empty?
        order.reload
      end
    end

    trait :completed do
      status { 'completed' }
      shipped_at { 3.days.ago }
      delivered_at { 1.day.ago }
      after(:create) do |order|
        create(:tire_order_item, tire_order: order) if order.tire_order_items.empty?
        order.reload
      end
    end

    trait :cancelled do
      status { 'cancelled' }
    end

    trait :with_items do
      after(:create) do |order|
        2.times do
          create(:tire_order_item, tire_order: order, supplier_tire_product: create(:supplier_tire_product, supplier: order.supplier))
        end
        order.reload
      end
    end

    trait :with_partner do
      association :partner
    end
  end
end

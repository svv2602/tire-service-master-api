class MakeUserIdOptionalInTireCarts < ActiveRecord::Migration[8.0]
  def change
    # Делаем поле user_id опциональным для поддержки гостевых корзин
    change_column_null :tire_carts, :user_id, true
    
    # Убираем уникальный индекс и создаем новый с условием для исключения NULL значений
    remove_index :tire_carts, :user_id if index_exists?(:tire_carts, :user_id)
    add_index :tire_carts, :user_id, unique: true, where: "user_id IS NOT NULL"
  end
end

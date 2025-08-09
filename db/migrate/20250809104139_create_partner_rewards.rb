class CreatePartnerRewards < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_rewards do |t|
      t.references :partner, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :reward_rule, null: false, foreign_key: true
      # Заказ может быть либо TireOrder (корзина) либо Order (интернет-магазин)
      t.references :tire_order, null: true, foreign_key: true
      t.references :order, null: true, foreign_key: true
      t.decimal :calculated_amount, precision: 10, scale: 2, null: false
      t.string :payment_status, null: false, default: 'pending' # 'pending', 'paid', 'cancelled'
      t.datetime :calculated_at, null: false
      t.datetime :paid_at
      t.text :notes

      t.timestamps
    end

    # Индексы для оптимизации (references уже создает индексы для FK)
    add_index :partner_rewards, :payment_status
    add_index :partner_rewards, :calculated_at

    # Проверка что указан хотя бы один тип заказа
    add_check_constraint :partner_rewards, 
                        "(tire_order_id IS NOT NULL) OR (order_id IS NOT NULL)",
                        name: "partner_rewards_order_type_check"
  end
end

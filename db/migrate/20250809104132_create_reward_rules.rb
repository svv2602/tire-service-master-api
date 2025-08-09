class CreateRewardRules < ActiveRecord::Migration[8.0]
  def change
    create_table :reward_rules do |t|
      t.references :partner_supplier_agreement, null: false, foreign_key: true
      t.string :rule_type, null: false # 'fixed_per_order', 'percentage', 'fixed_per_item'
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.text :conditions # JSON условия (бренды, диаметры, исключения)
      t.integer :priority, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.text :description

      t.timestamps
    end

    # Индексы для оптимизации
    add_index :reward_rules, :partner_supplier_agreement_id, name: 'index_reward_rules_on_agreement'
    add_index :reward_rules, [:rule_type, :active]
    add_index :reward_rules, :priority
  end
end

class CreateOperatorServicePoints < ActiveRecord::Migration[8.0]
  def change
    create_table :operator_service_points do |t|
      t.references :operator, null: false, foreign_key: true, comment: 'Ссылка на оператора'
      t.references :service_point, null: false, foreign_key: true, comment: 'Ссылка на сервисную точку'
      t.datetime :assigned_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'Дата и время назначения'
      t.boolean :is_active, null: false, default: true, comment: 'Активность привязки'

      t.timestamps
    end

    # Уникальный индекс для предотвращения дублирования привязок
    add_index :operator_service_points, [:operator_id, :service_point_id], 
              unique: true, 
              name: 'index_operator_service_points_unique'
    
    # Индекс для активных привязок
    add_index :operator_service_points, :is_active
  end
end

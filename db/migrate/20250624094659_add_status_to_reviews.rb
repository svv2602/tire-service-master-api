class AddStatusToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :status, :string, default: 'published', null: false
    add_index :reviews, :status
    
    # Устанавливаем статус на основе существующего поля is_published
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE reviews 
          SET status = CASE 
            WHEN is_published = true THEN 'published'
            ELSE 'pending'
          END
        SQL
      end
    end
  end
end

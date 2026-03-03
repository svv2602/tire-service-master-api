class CreateOnboardingProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :onboarding_progresses do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.jsonb :completed_steps, default: [], null: false
      t.boolean :welcome_shown, default: false, null: false

      t.timestamps
    end

    add_index :onboarding_progresses, :user_id, unique: true
  end
end

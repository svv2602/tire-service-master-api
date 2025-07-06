class MakePartnerIdOptionalInManagers < ActiveRecord::Migration[8.0]
  def change
    # Делаем partner_id опциональным для менеджеров сайта
    change_column_null :managers, :partner_id, true
  end
end

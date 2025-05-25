class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :phone, :first_name, :last_name, :middle_name, :last_login, 
             :is_active, :email_verified, :phone_verified, :created_at, :updated_at, :role, :profile

  def role
    object.role.name
  end

  def profile
    case object.role.name
    when 'admin'
      if object.administrator
        {
          position: object.administrator.position,
          access_level: object.administrator.access_level
        }
      else
        {}
      end
    when 'partner'
      if object.partner
        {
          company_name: object.partner.company_name,
          company_description: object.partner.company_description,
          contact_person: object.partner.contact_person,
          logo_url: object.partner.logo_url,
          website: object.partner.website
        }
      else
        {}
      end
    when 'manager'
      if object.manager
        {
          partner_id: object.manager.partner_id,
          access_level: object.manager.access_level,
          partner_name: object.manager.partner&.company_name
        }
      else
        {}
      end
    when 'client'
      if object.client
        {
          preferred_notification_method: object.client.preferred_notification_method,
          marketing_consent: object.client.marketing_consent
        }
      else
        {}
      end
    else
      {}
    end
  end
end

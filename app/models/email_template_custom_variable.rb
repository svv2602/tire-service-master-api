class EmailTemplateCustomVariable < ApplicationRecord
  belongs_to :email_template
  belongs_to :custom_variable
end

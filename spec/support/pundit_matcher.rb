require 'rspec/expectations'

# Добавляем методы для тестирования scope в Pundit политиках
module PunditScopeMatcher
  extend RSpec::Matchers::DSL

  # DSL для тестирования скоупов в политиках
  def permissions_for_scope(scope_name, &block)
    describe "scope #{scope_name}" do
      instance_eval(&block)
    end
  end
  
  # Делаем метод доступным в тестовых классах
  RSpec.configure do |config|
    config.extend PunditScopeMatcher, type: :policy
  end
end

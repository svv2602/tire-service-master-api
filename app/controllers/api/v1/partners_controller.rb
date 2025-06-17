module Api
  module V1
    class PartnersController < ApiController
      before_action :set_partner, only: [:show, :update, :destroy, :toggle_active]
      before_action :authorize_admin, except: [:index, :show, :create, :create_test, :toggle_active]
      skip_before_action :authenticate_request, only: [:index, :create_test, :create]
      
      # GET /api/v1/partners
      def index
        @partners = Partner.includes(:user, :region, :city).all
        
        # Поиск по имени компании, контактному лицу или номеру телефона пользователя (регистронезависимый)
        if params[:query].present?
          @partners = @partners.joins(:user).where(
            "LOWER(partners.company_name) LIKE LOWER(?) OR LOWER(partners.contact_person) LIKE LOWER(?) OR users.phone LIKE ?", 
            "%#{params[:query]}%", "%#{params[:query]}%", "%#{params[:query]}%"
          )
        end
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        offset = (page - 1) * per_page
        
        total_count = @partners.count
        @partners = @partners.offset(offset).limit(per_page)
        
        # Если нет партнеров, возвращаем пустой массив
        if @partners.empty?
          render json: {
            data: [],
            pagination: {
              current_page: page,
              total_pages: 0,
              total_count: 0,
              per_page: per_page
            }
          }
          return
        end
        
        total_pages = (total_count.to_f / per_page).ceil
        
        render json: {
          data: @partners.as_json(include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } }),
          pagination: {
            current_page: page,
            total_pages: total_pages,
            total_count: total_count,
            per_page: per_page
          }
        }
      end
      
      # GET /api/v1/partners/:id
      def show
        render json: @partner.as_json(include: { 
          user: { only: [:id, :email, :phone, :first_name, :last_name] },
          region: { only: [:id, :name, :code] },
          city: { only: [:id, :name] }
        })
      end
      
      # POST /api/v1/partners
      def create
        Rails.logger.info("Начало создания партнера с параметрами: #{params.inspect}")
        
        ActiveRecord::Base.transaction do
          # Сначала создаем пользователя, если user_id не указан
          if params[:user_id].blank? && params[:partner][:user_attributes].present?
            user_data = params[:partner][:user_attributes].permit(:email, :password, :phone, :first_name, :last_name)
            
            # Генерируем пароль, если он не был предоставлен
            user_data[:password] ||= SecureRandom.hex(8)
            # Сохраняем пароль для возможной отправки по email
            generated_password = user_data[:password]
            
            Rails.logger.info("Создание пользователя с данными: #{user_data.inspect}")
            
            @user = User.new(user_data)
            # Устанавливаем роль партнера (id: 4)
            @user.role_id = 4
            # Отключаем автоматическое создание партнера
            @user.skip_role_specific_record = true
            
            unless @user.save
              Rails.logger.error("Ошибка при создании пользователя: #{@user.errors.full_messages}")
              raise ActiveRecord::RecordInvalid.new(@user)
            end
            
            Rails.logger.info("Пользователь успешно создан с ID: #{@user.id}")
            
            # Создаем партнера с сохраненным пользователем
            partner_data = partner_params.except(:user_attributes)
            partner_data[:user_id] = @user.id
            
            Rails.logger.info("Создание партнера с данными: #{partner_data.inspect}")
            
            @partner = Partner.new(partner_data)
            
            unless @partner.save
              Rails.logger.error("Ошибка при создании партнера: #{@partner.errors.full_messages}")
              raise ActiveRecord::RecordInvalid.new(@partner)
            end
            
            Rails.logger.info("Партнер успешно создан с ID: #{@partner.id}")

            # Если это регистрация (не админ создает партнера), генерируем JWT токен
            if !current_user&.admin?
              token = Auth::JsonWebToken.encode_access_token(user_id: @user.id)
              render json: {
                tokens: { access: token },
                user: @user.as_json(only: [:id, :email, :first_name, :last_name, :role, :is_active]),
                partner: @partner.as_json(only: [:id])
              }, status: :created
              return
            end
          else
            # Если user_id указан, просто создаем партнера
            @partner = Partner.new(partner_params)
            @partner.user_id = params[:user_id]
            
            unless @partner.save
              raise ActiveRecord::RecordInvalid.new(@partner)
            end
          end
        end
        
        render json: @partner.as_json(include: { 
          user: { only: [:id, :email, :phone, :first_name, :last_name] },
          region: { only: [:id, :name, :code] },
          city: { only: [:id, :name] }
        }), status: :created
        
      rescue ActiveRecord::RecordInvalid => e
        errors = {}
        
        if e.record.is_a?(User)
          errors[:user] = e.record.errors.full_messages.map do |message|
            # Добавляем префикс "Пользователь:" для более ясного сообщения
            "Пользователь: #{message}"
          end
        elsif e.record.is_a?(Partner)
          errors[:partner] = e.record.errors.full_messages.map do |message|
            # Добавляем префикс "Компания:" для более ясного сообщения
            "Компания: #{message}"
          end
        end
        
        render json: { 
          errors: errors,
          message: "Не удалось создать партнера. Проверьте правильность введенных данных."
        }, status: :unprocessable_entity
      rescue StandardError => e
        render json: { 
          error: e.message,
          message: "Произошла ошибка при создании партнера." 
        }, status: :unprocessable_entity
      end
      
      # POST /api/v1/partners/create_test
      def create_test
        ActiveRecord::Base.transaction do
          # Создаем пользователя
          @user = User.create!(
            email: "partner_test_#{Time.now.to_i}@example.com",
            password: 'password',
            password_confirmation: 'password',
            first_name: 'Тест',
            last_name: 'Партнер',
            phone: "+38067#{Random.rand(1000000..9999999)}",
            role: UserRole.find_by(name: 'operator')
          )
          
          # Создаем партнера
          @partner = Partner.create!(
            user_id: @user.id,
            company_name: "Тестовая компания #{Time.now.to_i}",
            company_description: "Описание тестовой компании",
            contact_person: "Тест Партнер",
            logo_url: "https://via.placeholder.com/150",
            website: "http://test-company.com",
            tax_number: "12345678",
            legal_address: "ул. Тестовая, 123"
          )
        end
        
        render json: @partner.as_json(include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } }), status: :created
        
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      end
      
      # PUT /api/v1/partners/:id
      def update
        Rails.logger.info("Обновление партнера ID: #{params[:id]}")
        Rails.logger.info("Исходные параметры: #{params[:partner].inspect}")
        Rails.logger.info("Обработанные параметры: #{partner_params.inspect}")
        
        ActiveRecord::Base.transaction do
          # Обновляем данные пользователя, если они переданы
          if params[:partner][:user].present? && @partner.user
            user_update_params = params.require(:partner).require(:user).permit(:email, :phone, :first_name, :last_name)
            
            unless @partner.user.update(user_update_params)
              raise ActiveRecord::RecordInvalid.new(@partner.user)
            end
          end
          
          # Обновляем данные партнера
          unless @partner.update(partner_params)
            raise ActiveRecord::RecordInvalid.new(@partner)
          end
        end
        
        Rails.logger.info("Партнер после обновления: region_id=#{@partner.region_id}, city_id=#{@partner.city_id}")
        
        render json: @partner.as_json(include: { 
          user: { only: [:id, :email, :phone, :first_name, :last_name] },
          region: { only: [:id, :name, :code] },
          city: { only: [:id, :name] }
        })
        
      rescue ActiveRecord::RecordInvalid => e
        errors = {}
        
        if e.record.is_a?(User)
          errors[:user] = e.record.errors.full_messages.map do |message|
            # Добавляем префикс "Пользователь:" для более ясного сообщения
            "Пользователь: #{message}"
          end
        elsif e.record.is_a?(Partner)
          errors[:partner] = e.record.errors.full_messages.map do |message|
            # Добавляем префикс "Компания:" для более ясного сообщения
            "Компания: #{message}"
          end
        end
        
        render json: { 
          errors: errors,
          message: "Не удалось обновить партнера. Проверьте правильность введенных данных."
        }, status: :unprocessable_entity
      rescue StandardError => e
        render json: { 
          error: e.message,
          message: "Произошла ошибка при обновлении партнера." 
        }, status: :unprocessable_entity
      end
      
      # PATCH /api/v1/partners/:id/toggle_active
      def toggle_active
        # Проверяем права доступа (только админ или сам партнер)
        unless current_user && (current_user.admin? || current_user.id == @partner.user_id)
          render json: { 
            error: 'У вас нет прав для выполнения этого действия',
            message: 'Для выполнения этого действия требуются права администратора или владельца аккаунта.'
          }, status: :unauthorized
          return
        end
        
        # Параметр active можно передать явно, иначе инвертируем текущий статус
        new_active_status = params[:active].nil? ? !@partner.is_active : ActiveRecord::Type::Boolean.new.cast(params[:active])
        
        # Получаем количество сервисных точек и менеджеров, которые будут затронуты
        service_points_count = @partner.service_points.count
        managers_count = @partner.managers.count
        
        # Добавляем логгирование для отладки
        Rails.logger.info("Changing partner status. Partner ID: #{@partner.id}, Current status: #{@partner.is_active}, New status: #{new_active_status}")
        
        # Вызываем метод изменения активности
        if @partner.toggle_active(new_active_status)
          status_text = new_active_status ? "активирован" : "деактивирован"
          
          # Собираем информацию о выполненных изменениях для ответа
          changes = {
            partner_status: status_text,
            affected_service_points: service_points_count,
            affected_managers: managers_count
          }
          
          render json: {
            success: true,
            message: "Партнер успешно #{status_text}. Затронуто #{service_points_count} сервисных точек и #{managers_count} менеджеров.",
            partner: @partner.as_json(include: { user: { only: [:id, :email, :phone, :first_name, :last_name, :role_id] } }),
            changes: changes
          }
        else
          render json: { 
            success: false,
            error: "Не удалось изменить статус партнера",
            message: "Произошла ошибка при обновлении статуса партнера. Пожалуйста, попробуйте еще раз позже."
          }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/partners/:id
      def destroy
        # Проверяем, есть ли у партнера сервисные точки
        if @partner.service_points.exists?
          render json: { 
            error: 'Невозможно удалить партнера, так как у него есть сервисные точки. Удалите сначала сервисные точки.',
            service_points_count: @partner.service_points.count,
            service_points: @partner.service_points.pluck(:id, :name),
            message: "Перед удалением партнера необходимо удалить все его сервисные точки (#{@partner.service_points.count} шт.)"
          }, status: :unprocessable_entity
          return
        end
        
        # Сохраняем ID пользователя для последующего удаления
        user_id = @partner.user_id
        
        begin
          ActiveRecord::Base.transaction do
            # Удаляем партнера
            @partner.destroy!
            
            # Удаляем связанного пользователя, если он существует
            user = User.find_by(id: user_id)
            user&.destroy!
          end
          
          head :no_content
        rescue ActiveRecord::StatementInvalid => e
          # Обрабатываем ошибки SQL
          error_message = "Ошибка при удалении партнера: #{e.message}"
          Rails.logger.error(error_message)
          render json: { 
            error: error_message,
            message: "Не удалось удалить партнера из-за ошибки базы данных. Обратитесь к администратору системы."
          }, status: :unprocessable_entity
        rescue StandardError => e
          error_message = "Произошла ошибка при удалении партнера: #{e.message}"
          Rails.logger.error(error_message)
          render json: { 
            error: error_message,
            message: "Не удалось удалить партнера. Пожалуйста, попробуйте еще раз позже."
          }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_partner
        @partner = Partner.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { 
          error: "Партнер с ID #{params[:id]} не найден",
          message: "Партнер с указанным идентификатором не существует в системе."
        }, status: :not_found
      end
      
      def partner_params
        permitted_params = params.require(:partner).permit(
          :company_name, :company_description, :contact_person, 
          :logo_url, :website, :tax_number, :legal_address,
          :region_id, :city_id, :is_active,
          user_attributes: [:email, :password, :phone, :first_name, :last_name, :role_id]
        )
        
        # Проверка и установка значений по умолчанию
        permitted_params[:tax_number] = nil if permitted_params[:tax_number].blank?
        permitted_params[:region_id] = nil if permitted_params[:region_id].blank?
        permitted_params[:city_id] = nil if permitted_params[:city_id].blank?
        
        permitted_params
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { 
            error: 'У вас нет прав для выполнения этого действия',
            message: 'Для выполнения этого действия требуются права администратора.'
          }, status: :unauthorized
        end
      end
    end
  end
end 
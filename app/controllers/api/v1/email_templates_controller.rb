class Api::V1::EmailTemplatesController < Api::V1::BaseController
  before_action :authenticate_request
  before_action :ensure_admin!
  before_action :set_email_template, only: [:show, :update, :destroy, :toggle_status, :preview]

  # GET /api/v1/email_templates
  def index
    @email_templates = policy_scope(EmailTemplate)
    
    # Фильтрация
    @email_templates = @email_templates.by_type(params[:template_type]) if params[:template_type].present?
    @email_templates = @email_templates.by_language(params[:language]) if params[:language].present?
    @email_templates = @email_templates.active if params[:active] == 'true'
    @email_templates = @email_templates.where(is_active: false) if params[:active] == 'false'
    
    # Поиск
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @email_templates = @email_templates.where(
        "name ILIKE ? OR subject ILIKE ? OR body ILIKE ?", 
        search_term, search_term, search_term
      )
    end
    
    # Сортировка
    sort_by = params[:sort_by] || 'created_at'
    sort_order = params[:sort_order] || 'desc'
    @email_templates = @email_templates.order("#{sort_by} #{sort_order}")
    
    # Пагинация
    page = [params[:page].to_i, 1].max
    per_page = [params[:per_page].to_i, 100].min
    per_page = 20 if per_page <= 0
    
    total_count = @email_templates.count
    @email_templates = @email_templates.limit(per_page).offset((page - 1) * per_page)
    
    # Вычисляем общее количество страниц
    total_pages = (total_count.to_f / per_page).ceil
    
    # Статистика
    stats = {
      total: EmailTemplate.count,
      active: EmailTemplate.active.count,
      inactive: EmailTemplate.where(is_active: false).count,
      by_language: EmailTemplate.group(:language).count,
      by_type: EmailTemplate.group(:template_type).count
    }
    
    render json: {
      data: @email_templates.map { |template| serialize_template(template) },
      pagination: {
        current_page: page,
        total_pages: total_pages,
        total_count: total_count,
        per_page: per_page
      },
      stats: stats,
      available_types: EmailTemplate.template_types,
      available_languages: %w[uk ru en]
    }
  end

  # GET /api/v1/email_templates/:id
  def show
    authorize @email_template
    
    render json: {
      email_template: serialize_template(@email_template, detailed: true),
      available_variables: get_available_variables(@email_template.template_type),
      usage_stats: get_usage_stats(@email_template)
    }
  end

  # POST /api/v1/email_templates
  def create
    @email_template = EmailTemplate.new(email_template_params)
    authorize @email_template
    
    if @email_template.save
      Rails.logger.info "📧 Email template created: #{@email_template.name} (#{@email_template.template_type})"
      
      render json: {
        message: 'Шаблон успешно создан',
        email_template: serialize_template(@email_template, detailed: true)
      }, status: :created
    else
      render json: {
        message: 'Ошибка создания шаблона',
        errors: @email_template.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/email_templates/:id
  def update
    authorize @email_template
    
    if @email_template.update(email_template_params)
      Rails.logger.info "📧 Email template updated: #{@email_template.name} (#{@email_template.template_type})"
      
      render json: {
        message: 'Шаблон успешно обновлен',
        email_template: serialize_template(@email_template, detailed: true)
      }
    else
      render json: {
        message: 'Ошибка обновления шаблона',
        errors: @email_template.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/email_templates/:id
  def destroy
    authorize @email_template
    
    template_name = @email_template.name
    
    if @email_template.destroy
      Rails.logger.info "📧 Email template deleted: #{template_name}"
      
      render json: {
        message: 'Шаблон успешно удален'
      }
    else
      render json: {
        message: 'Ошибка удаления шаблона',
        errors: @email_template.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/email_templates/:id/toggle_status
  def toggle_status
    authorize @email_template
    
    @email_template.update!(is_active: !@email_template.is_active)
    
    status_text = @email_template.is_active? ? 'активирован' : 'деактивирован'
    Rails.logger.info "📧 Email template #{status_text}: #{@email_template.name}"
    
    render json: {
      message: "Шаблон #{status_text}",
      email_template: serialize_template(@email_template)
    }
  end

  # POST /api/v1/email_templates/:id/preview
  def preview
    authorize @email_template
    
    # Получаем тестовые данные для предварительного просмотра
    test_variables = get_test_variables(@email_template.template_type)
    
    # Объединяем с переданными переменными
    variables = test_variables.merge(params[:variables] || {})
    
    # Рендерим шаблон
    rendered = @email_template.render_with_all_variables(variables)
    
    render json: {
      preview: {
        subject: rendered[:subject],
        body: rendered[:body],
        variables_used: variables,
        available_variables: get_available_variables(@email_template.template_type)
      }
    }
  end

  # POST /api/v1/email_templates/:id/test_send
  def test_send
    authorize @email_template
    
    recipient_email = params[:recipient_email] || current_user.email
    
    unless recipient_email.present? && recipient_email.match?(URI::MailTo::EMAIL_REGEXP)
      return render json: {
        message: 'Некорректный email получателя'
      }, status: :unprocessable_entity
    end
    
    begin
      # Отправляем тестовое письмо
      test_variables = get_test_variables(@email_template.template_type)
      rendered = @email_template.render_with_all_variables(test_variables)
      
      # Создаем тестовое письмо
      mail = ActionMailer::Base.mail(
        to: recipient_email,
        from: ENV.fetch('SMTP_FROM_EMAIL', 'noreply@tireservice.ua'),
        subject: "[ТЕСТ] #{rendered[:subject]}",
        body: rendered[:body],
        content_type: 'text/html; charset=UTF-8'
      )
      
      mail.deliver_now
      
      Rails.logger.info "📧 Test email sent: #{@email_template.name} to #{recipient_email}"
      
      render json: {
        message: 'Тестовое письмо отправлено',
        recipient: recipient_email
      }
    rescue => e
      Rails.logger.error "❌ Test email failed: #{e.message}"
      
      render json: {
        message: 'Ошибка отправки тестового письма',
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/email_templates/template_types
  def template_types
    types_array = EmailTemplate.template_types.map do |key, label|
      { value: key, label: label }
    end
    
    render json: {
      data: types_array,
      available_languages: %w[uk ru en]
    }
  end

  private

  def set_email_template
    @email_template = EmailTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Шаблон не найден' }, status: :not_found
  end

  def email_template_params
    params.require(:email_template).permit(
      :name, :subject, :body, :template_type, :language, :is_active, :variables
    )
  end

  def serialize_template(template, detailed: false)
    data = {
      id: template.id,
      name: template.name,
      subject: template.subject,
      template_type: template.template_type,
      template_type_name: template.template_type_name,
      language: template.language,
      is_active: template.is_active,
      status_text: template.status_text,
      variables_array: template.variables_array,
      created_at: template.created_at,
      updated_at: template.updated_at
    }
    
    if detailed
      data.merge!({
        body: template.body,
        variables: template.variables_array,
        custom_variables: template.custom_variables.active.map do |cv|
          {
            id: cv.id,
            name: cv.name,
            placeholder: cv.variable_placeholder,
            description: cv.description,
            example_value: cv.example_value
          }
        end
      })
    end
    
    data
  end

  def get_available_variables(template_type)
    case template_type
    when /booking/
      %w[booking_id booking_number booking_date start_time end_time 
         service_point_name service_point_address city_name
         client_first_name client_last_name client_phone client_email
         car_brand car_model license_plate status]
    when /review/
      %w[review_id review_number rating rating_stars comment status status_text
         client_first_name client_last_name service_point_name
         created_date created_time]
    when /service_point/
      %w[service_point_id service_point_name service_point_address 
         city_name work_status work_status_text is_active
         created_date updated_date]
    else
      %w[client_first_name client_last_name service_point_name city_name]
    end
  end

  def get_test_variables(template_type)
    base_vars = {
      client_first_name: 'Олександр',
      client_last_name: 'Петренко',
      client_phone: '+380501234567',
      client_email: 'test@example.com',
      service_point_name: 'ШиноСервіс Експрес',
      service_point_address: 'вул. Хрещатик, 1',
      city_name: 'Київ',
      created_date: Date.current.strftime('%d.%m.%Y'),
      created_time: Time.current.strftime('%H:%M')
    }
    
    case template_type
    when /booking/
      base_vars.merge({
        booking_id: '#123',
        booking_number: '123',
        booking_date: Date.tomorrow.strftime('%d.%m.%Y'),
        start_time: '10:00',
        end_time: '11:00',
        car_brand: 'Toyota',
        car_model: 'Camry',
        license_plate: 'AA1234BB',
        status: 'confirmed'
      })
    when /review/
      base_vars.merge({
        review_id: '#456',
        review_number: '456',
        rating: '5',
        rating_stars: '⭐⭐⭐⭐⭐',
        comment: 'Відмінний сервіс! Рекомендую!',
        status: 'published',
        status_text: 'Опубліковано'
      })
    when /service_point/
      base_vars.merge({
        service_point_id: '#789',
        service_point_name: 'ШиноСервіс Центр',
        work_status: 'working',
        work_status_text: 'Працює',
        is_active: 'Активна',
        updated_date: Date.current.strftime('%d.%m.%Y')
      })
    else
      base_vars
    end
  end

  def get_usage_stats(template)
    # В будущем можно добавить статистику использования шаблонов
    {
      emails_sent_today: 0,
      emails_sent_week: 0,
      emails_sent_month: 0,
      last_sent_at: nil
    }
  end
end 
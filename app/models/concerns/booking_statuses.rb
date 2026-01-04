module BookingStatuses
  extend ActiveSupport::Concern

  # Константы статусов
  STATUSES = {
    pending: {
      name: 'pending',
      display_name: 'В ожидании',
      description: 'Бронирование создано, ожидает подтверждения',
      color: '#FFC107',
      sort_order: 1
    },
    confirmed: {
      name: 'confirmed', 
      display_name: 'Подтверждено',
      description: 'Бронирование подтверждено сервисной точкой',
      color: '#4CAF50',
      sort_order: 2
    },
    in_progress: {
      name: 'in_progress',
      display_name: 'В процессе', 
      description: 'Услуга выполняется',
      color: '#2196F3',
      sort_order: 3
    },
    completed: {
      name: 'completed',
      display_name: 'Завершено',
      description: 'Услуга успешно завершена',
      color: '#8BC34A',
      sort_order: 4
    },
    cancelled_by_client: {
      name: 'cancelled_by_client',
      display_name: 'Отменено клиентом',
      description: 'Бронирование отменено клиентом',
      color: '#F44336',
      sort_order: 5
    },
    cancelled_by_partner: {
      name: 'cancelled_by_partner',
      display_name: 'Отменено партнером',
      description: 'Бронирование отменено сервисной точкой',
      color: '#FF5722',
      sort_order: 6
    },
    no_show: {
      name: 'no_show',
      display_name: 'Не явился',
      description: 'Клиент не явился на прием',
      color: '#9C27B0',
      sort_order: 7
    }
  }.freeze

  # Группы статусов
  ACTIVE_STATUSES = [:pending, :confirmed, :in_progress].freeze
  COMPLETED_STATUSES = [:completed].freeze
  CANCELLED_STATUSES = [:cancelled_by_client, :cancelled_by_partner, :no_show].freeze
  FINAL_STATUSES = [:completed, :cancelled_by_client, :cancelled_by_partner, :no_show].freeze

  class_methods do
    # Получить все статусы
    def all_statuses
      STATUSES
    end

    # Получить статус по имени
    def status_by_name(name)
      STATUSES[name.to_sym]
    end

    # Получить отображаемое имя статуса
    def display_name_for(status_name)
      status = status_by_name(status_name)
      status ? status[:display_name] : status_name.to_s.humanize
    end

    # Получить цвет статуса
    def color_for(status_name)
      status = status_by_name(status_name)
      status ? status[:color] : '#9E9E9E'
    end

    # Проверки статусов
    def active_status?(status_name)
      ACTIVE_STATUSES.include?(status_name.to_sym)
    end

    def completed_status?(status_name)
      COMPLETED_STATUSES.include?(status_name.to_sym)
    end

    def cancelled_status?(status_name)
      CANCELLED_STATUSES.include?(status_name.to_sym)
    end

    def final_status?(status_name)
      FINAL_STATUSES.include?(status_name.to_sym)
    end

    # Получить список имен статусов для определенной группы
    def active_status_names
      ACTIVE_STATUSES.map(&:to_s)
    end

    def completed_status_names
      COMPLETED_STATUSES.map(&:to_s)
    end

    def cancelled_status_names
      CANCELLED_STATUSES.map(&:to_s)
    end

    # Валидация статуса
    def valid_status?(status_name)
      STATUSES.key?(status_name.to_sym)
    end

    # Получить следующие возможные статусы
    def possible_transitions_from(current_status)
      case current_status.to_sym
      when :pending
        [:confirmed, :cancelled_by_client, :cancelled_by_partner]
      when :confirmed
        [:in_progress, :completed, :cancelled_by_client, :cancelled_by_partner, :no_show]
      when :in_progress
        [:completed, :cancelled_by_partner]
      else
        []
      end
    end

    # Проверить возможность перехода
    def can_transition?(from_status, to_status)
      possible_transitions_from(from_status).include?(to_status.to_sym)
    end
  end

  included do
    # Валидация статуса
    validates :status, inclusion: { 
      in: STATUSES.keys.map(&:to_s), 
      message: 'недопустимый статус' 
    }

    # Скоупы для удобства
    scope :with_status, ->(status_name) { where(status: status_name.to_s) }
    scope :active_bookings, -> { where(status: ACTIVE_STATUSES.map(&:to_s)) }
    scope :completed_bookings, -> { where(status: COMPLETED_STATUSES.map(&:to_s)) }
    scope :cancelled_bookings, -> { where(status: CANCELLED_STATUSES.map(&:to_s)) }
    scope :final_bookings, -> { where(status: FINAL_STATUSES.map(&:to_s)) }
  end

  # Методы экземпляра
  def status_display_name
    self.class.display_name_for(status)
  end

  def status_color
    self.class.color_for(status)
  end

  def active_status?
    self.class.active_status?(status)
  end

  def completed_status?
    self.class.completed_status?(status)
  end

  def cancelled_status?
    self.class.cancelled_status?(status)
  end

  def final_status?
    self.class.final_status?(status)
  end

  def can_transition_to?(new_status)
    self.class.can_transition?(status, new_status)
  end

  def possible_transitions
    self.class.possible_transitions_from(status)
  end

  # Individual status predicate methods
  def pending?
    status == 'pending'
  end

  def confirmed?
    status == 'confirmed'
  end

  def in_progress?
    status == 'in_progress'
  end

  def completed?
    status == 'completed'
  end

  def cancelled_by_client?
    status == 'cancelled_by_client'
  end

  def cancelled_by_partner?
    status == 'cancelled_by_partner'
  end

  def no_show?
    status == 'no_show'
  end
end 
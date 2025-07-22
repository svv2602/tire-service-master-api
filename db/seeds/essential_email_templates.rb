puts '📧 СОЗДАНИЕ ОСНОВНЫХ EMAIL ШАБЛОНОВ'
puts '=' * 50

# Удаляем все существующие шаблоны
puts 'Удаляем существующие шаблоны...'
EmailTemplate.destroy_all
puts "Удалено шаблонов: #{EmailTemplate.count}"

# Массив основных шаблонов (только те что реально используются в системе)
essential_templates = [
  # 1. ПОДТВЕРЖДЕНИЕ БРОНИРОВАНИЯ
  {
    name: 'Підтвердження бронювання',
    template_type: 'booking_confirmation',
    language: 'uk',
    subject: 'Підтверджено: бронювання #{booking_id} на {booking_date}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Вітаємо, {client_name}!</h2>
    
    <div style="background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #2e7d32; margin-top: 0;">✅ ВАШЕ БРОНЮВАННЯ ПІДТВЕРДЖЕНО</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <h4>📅 ДЕТАЛІ ЗАПИСУ:</h4>
      <ul style="list-style: none; padding: 0;">
        <li><strong>Номер бронювання:</strong> {booking_id}</li>
        <li><strong>Дата:</strong> {booking_date}</li>
        <li><strong>Час:</strong> {booking_time}</li>
        <li><strong>Сервісна точка:</strong> {service_point_name}</li>
        <li><strong>Адреса:</strong> {service_point_address}</li>
        <li><strong>Послуга:</strong> {service_name}</li>
      </ul>
    </div>
    
    <div style="margin: 20px 0;">
      <h4>🚗 АВТОМОБІЛЬ:</h4>
      <p><strong>{car_brand} {car_model}</strong> ({car_year}р.)<br>
      Номер: <strong>{license_plate}</strong></p>
    </div>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #856404;">⚠️ ВАЖЛИВО:</h4>
      <ul>
        <li>Прибудьте за 10 хвилин до призначеного часу</li>
        <li>Мајте при собі документи на автомобіль</li>
        <li>У разі запізнення - телефонуйте заздалегідь</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p><strong>📞 Контакти сервісної точки:</strong><br>
      Телефон: <strong>{service_point_phone}</strong></p>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>З повагою,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },
  
  {
    name: 'Подтверждение бронирования',
    template_type: 'booking_confirmation',
    language: 'ru',
    subject: 'Подтверждено: бронирование #{booking_id} на {booking_date}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Здравствуйте, {client_name}!</h2>
    
    <div style="background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #2e7d32; margin-top: 0;">✅ ВАШЕ БРОНИРОВАНИЕ ПОДТВЕРЖДЕНО</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <h4>📅 ДЕТАЛИ ЗАПИСИ:</h4>
      <ul style="list-style: none; padding: 0;">
        <li><strong>Номер бронирования:</strong> {booking_id}</li>
        <li><strong>Дата:</strong> {booking_date}</li>
        <li><strong>Время:</strong> {booking_time}</li>
        <li><strong>Сервисная точка:</strong> {service_point_name}</li>
        <li><strong>Адрес:</strong> {service_point_address}</li>
        <li><strong>Услуга:</strong> {service_name}</li>
      </ul>
    </div>
    
    <div style="margin: 20px 0;">
      <h4>🚗 АВТОМОБИЛЬ:</h4>
      <p><strong>{car_brand} {car_model}</strong> ({car_year}г.)<br>
      Номер: <strong>{license_plate}</strong></p>
    </div>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #856404;">⚠️ ВАЖНО:</h4>
      <ul>
        <li>Приезжайте за 10 минут до назначенного времени</li>
        <li>Имейте при себе документы на автомобиль</li>
        <li>В случае опоздания - звоните заранее</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p><strong>📞 Контакты сервисной точки:</strong><br>
      Телефон: <strong>{service_point_phone}</strong></p>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>С уважением,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  # 2. ОТМЕНА БРОНИРОВАНИЯ
  {
    name: 'Скасування бронювання',
    template_type: 'booking_cancelled',
    language: 'uk',
    subject: 'Бронювання скасовано - {booking_id}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">{client_name}, повідомляємо про скасування</h2>
    
    <div style="background: #ffebee; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #c62828; margin-top: 0;">❌ СКАСОВАНЕ БРОНЮВАННЯ</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <ul style="list-style: none; padding: 0;">
        <li><strong>Номер:</strong> {booking_id}</li>
        <li><strong>Дата:</strong> {booking_date}</li>
        <li><strong>Час:</strong> {booking_time}</li>
        <li><strong>Сервісна точка:</strong> {service_point_name}</li>
      </ul>
    </div>
    
    <div style="background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #1565c0;">💡 ПОТРІБНА ДОПОМОГА?</h4>
      <p>Ви можете створити нове бронювання або звернутися до нашої служби підтримки.</p>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p><strong>📞 Служба підтримки:</strong><br>
      Email: <a href="mailto:{support_email}" style="color: #2c5aa0;">{support_email}</a><br>
      Телефон: <strong>{support_phone}</strong></p>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>З повагою,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  {
    name: 'Отмена бронирования',
    template_type: 'booking_cancelled',
    language: 'ru',
    subject: 'Бронирование отменено - {booking_id}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">{client_name}, уведомляем об отмене</h2>
    
    <div style="background: #ffebee; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #c62828; margin-top: 0;">❌ ОТМЕНЕННОЕ БРОНИРОВАНИЕ</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <ul style="list-style: none; padding: 0;">
        <li><strong>Номер:</strong> {booking_id}</li>
        <li><strong>Дата:</strong> {booking_date}</li>
        <li><strong>Время:</strong> {booking_time}</li>
        <li><strong>Сервисная точка:</strong> {service_point_name}</li>
      </ul>
    </div>
    
    <div style="background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #1565c0;">💡 НУЖНА ПОМОЩЬ?</h4>
      <p>Вы можете создать новое бронирование или обратиться в нашу службу поддержки.</p>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p><strong>📞 Служба поддержки:</strong><br>
      Email: <a href="mailto:{support_email}" style="color: #2c5aa0;">{support_email}</a><br>
      Телефон: <strong>{support_phone}</strong></p>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>С уважением,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  # 3. НАПОМИНАНИЕ О ЗАПИСИ
  {
    name: 'Нагадування про запис',
    template_type: 'booking_reminder',
    language: 'uk',
    subject: 'Нагадування: ваш запис завтра о {booking_time}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Доброго дня, {client_name}!</h2>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #856404; margin-top: 0;">⏰ НАГАДУЄМО ПРО ВАШ ЗАПИС</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <h4>📅 ЗАВТРА, {booking_date} о {booking_time}</h4>
      <ul style="list-style: none; padding: 0;">
        <li><strong>🏢 Сервісна точка:</strong> {service_point_name}</li>
        <li><strong>📍 Адреса:</strong> {service_point_address}</li>
        <li><strong>🔧 Послуга:</strong> {service_name}</li>
        <li><strong>🚗 Автомобіль:</strong> {car_brand} {car_model} ({license_plate})</li>
      </ul>
    </div>
    
    <div style="background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #2e7d32;">✅ ПІДГОТУЙТЕСЯ ДО ВІЗИТУ:</h4>
      <ul>
        <li>Прибудьте за 10 хвилин до призначеного часу</li>
        <li>Візьміть документи на автомобіль</li>
        <li>Підготуйте ключі від авто</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 30px 0; background: #e3f2fd; padding: 15px; border-radius: 5px;">
      <p><strong>📞 Контакти сервісної точки:</strong><br>
      Телефон: <strong>{service_point_phone}</strong></p>
      <p style="margin-top: 15px;"><strong>Потрібно перенести запис?</strong><br>
      Зателефонуйте нам заздалегідь!</p>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>З повагою,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  {
    name: 'Напоминание о записи',
    template_type: 'booking_reminder',
    language: 'ru',
    subject: 'Напоминание: ваша запись завтра в {booking_time}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Добрый день, {client_name}!</h2>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #856404; margin-top: 0;">⏰ НАПОМИНАЕМ О ВАШЕЙ ЗАПИСИ</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <h4>📅 ЗАВТРА, {booking_date} в {booking_time}</h4>
      <ul style="list-style: none; padding: 0;">
        <li><strong>🏢 Сервисная точка:</strong> {service_point_name}</li>
        <li><strong>📍 Адрес:</strong> {service_point_address}</li>
        <li><strong>🔧 Услуга:</strong> {service_name}</li>
        <li><strong>🚗 Автомобиль:</strong> {car_brand} {car_model} ({license_plate})</li>
      </ul>
    </div>
    
    <div style="background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #2e7d32;">✅ ПОДГОТОВЬТЕСЬ К ВИЗИТУ:</h4>
      <ul>
        <li>Приезжайте за 10 минут до назначенного времени</li>
        <li>Возьмите документы на автомобиль</li>
        <li>Подготовьте ключи от авто</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 30px 0; background: #e3f2fd; padding: 15px; border-radius: 5px;">
      <p><strong>📞 Контакты сервисной точки:</strong><br>
      Телефон: <strong>{service_point_phone}</strong></p>
      <p style="margin-top: 15px;"><strong>Нужно перенести запись?</strong><br>
      Позвоните нам заранее!</p>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>С уважением,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  # 4. СБРОС ПАРОЛЯ (КЛЮЧЕВОЙ ШАБЛОН!)
  {
    name: 'Скидання пароля',
    template_type: 'password_reset',
    language: 'uk',
    subject: 'Скидання пароля - {company_name}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Вітаємо, {client_name}!</h2>
    
    <p>Ви запросили скидання пароля для вашого облікового запису.</p>
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #1565c0; margin-top: 0;">🔐 ДЛЯ СКИДАННЯ ПАРОЛЯ:</h3>
      <p>Перейдіть за посиланням нижче та створіть новий пароль:</p>
      
      <div style="text-align: center; margin: 20px 0;">
        <a href="{reset_url}" style="background: #2c5aa0; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">
          🔑 Скинути пароль
        </a>
      </div>
    </div>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #856404;">⚠️ БЕЗПЕКА:</h4>
      <ul>
        <li>Посилання дійсне протягом <strong>2 годин</strong></li>
        <li>Якщо ви не запитували скидання, проігноруйте цей лист</li>
        <li>Не передавайте це посилання іншим особам</li>
      </ul>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4>📞 ПОТРІБНА ДОПОМОГА?</h4>
      <p>Зв'яжіться з нашою службою підтримки:</p>
      <ul style="list-style: none; padding: 0;">
        <li><strong>Email:</strong> <a href="mailto:{support_email}" style="color: #2c5aa0;">{support_email}</a></li>
        <li><strong>Телефон:</strong> {support_phone}</li>
      </ul>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>З повагою,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  {
    name: 'Сброс пароля',
    template_type: 'password_reset',
    language: 'ru',
    subject: 'Сброс пароля - {company_name}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Здравствуйте, {client_name}!</h2>
    
    <p>Вы запросили сброс пароля для вашей учетной записи.</p>
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #1565c0; margin-top: 0;">🔐 ДЛЯ СБРОСА ПАРОЛЯ:</h3>
      <p>Перейдите по ссылке ниже и создайте новый пароль:</p>
      
      <div style="text-align: center; margin: 20px 0;">
        <a href="{reset_url}" style="background: #2c5aa0; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">
          🔑 Сбросить пароль
        </a>
      </div>
    </div>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #856404;">⚠️ БЕЗОПАСНОСТЬ:</h4>
      <ul>
        <li>Ссылка действительна в течение <strong>2 часов</strong></li>
        <li>Если вы не запрашивали сброс, игнорируйте это письмо</li>
        <li>Не передавайте эту ссылку другим лицам</li>
      </ul>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4>📞 НУЖНА ПОМОЩЬ?</h4>
      <p>Свяжитесь с нашей службой поддержки:</p>
      <ul style="list-style: none; padding: 0;">
        <li><strong>Email:</strong> <a href="mailto:{support_email}" style="color: #2c5aa0;">{support_email}</a></li>
        <li><strong>Телефон:</strong> {support_phone}</li>
      </ul>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>С уважением,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  # 5. ЗАВЕРШЕНИЕ ОБСЛУЖИВАНИЯ
  {
    name: 'Завершення обслуговування',
    template_type: 'service_completed',
    language: 'uk',
    subject: 'Обслуговування завершено - {booking_id}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Вітаємо, {client_name}!</h2>
    
    <div style="background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #2e7d32; margin-top: 0;">✅ ВАШЕ ОБСЛУГОВУВАННЯ ЗАВЕРШЕНО</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <ul style="list-style: none; padding: 0;">
        <li><strong>📅 Дата:</strong> {booking_date} о {booking_time}</li>
        <li><strong>🏢 Сервісна точка:</strong> {service_point_name}</li>
        <li><strong>🔧 Послуга:</strong> {service_name}</li>
        <li><strong>🚗 Автомобіль:</strong> {car_brand} {car_model} ({license_plate})</li>
      </ul>
    </div>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #856404;">⭐ ПОДІЛІТЬСЯ ВРАЖЕННЯМИ</h4>
      <p>Ваша думка важлива для нас! Будь ласка, залиште відгук про якість обслуговування.</p>
      
      <div style="text-align: center; margin: 15px 0;">
        <a href="{website_url}/reviews/new?booking_id={booking_id}" style="background: #ff9800; color: white; padding: 10px 25px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">
          ⭐ Залишити відгук
        </a>
      </div>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p><strong>Дякуємо за довіру!</strong><br>
      Будемо раді бачити вас знову.</p>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>З повагою,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  {
    name: 'Завершение обслуживания',
    template_type: 'service_completed',
    language: 'ru',
    subject: 'Обслуживание завершено - {booking_id}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Здравствуйте, {client_name}!</h2>
    
    <div style="background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #2e7d32; margin-top: 0;">✅ ВАШЕ ОБСЛУЖИВАНИЕ ЗАВЕРШЕНО</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <ul style="list-style: none; padding: 0;">
        <li><strong>📅 Дата:</strong> {booking_date} в {booking_time}</li>
        <li><strong>🏢 Сервисная точка:</strong> {service_point_name}</li>
        <li><strong>🔧 Услуга:</strong> {service_name}</li>
        <li><strong>🚗 Автомобиль:</strong> {car_brand} {car_model} ({license_plate})</li>
      </ul>
    </div>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #856404;">⭐ ПОДЕЛИТЕСЬ ВПЕЧАТЛЕНИЯМИ</h4>
      <p>Ваше мнение важно для нас! Пожалуйста, оставьте отзыв о качестве обслуживания.</p>
      
      <div style="text-align: center; margin: 15px 0;">
        <a href="{website_url}/reviews/new?booking_id={booking_id}" style="background: #ff9800; color: white; padding: 10px 25px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">
          ⭐ Оставить отзыв
        </a>
      </div>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p><strong>Спасибо за доверие!</strong><br>
      Будем рады видеть вас снова.</p>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>С уважением,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  # 6. ЗАПРОС ОТЗЫВА
  {
    name: 'Запит відгуку',
    template_type: 'review_request',
    language: 'uk',
    subject: 'Поділіться враженнями про обслуговування',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Вітаємо, {client_name}!</h2>
    
    <p>Дякуємо за відвідування <strong>{service_point_name}</strong>!</p>
    
    <div style="background: #fff3cd; padding: 20px; border-radius: 5px; margin: 20px 0; text-align: center;">
      <h3 style="color: #856404; margin-top: 0;">⭐ ПОДІЛІТЬСЯ ВРАЖЕННЯМИ</h3>
      <p>Ваша думка допомагає нам ставати кращими!</p>
      
      <div style="margin: 20px 0;">
        <a href="{website_url}/reviews/new?booking_id={booking_id}" style="background: #ff9800; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold; font-size: 16px;">
          ⭐ Залишити відгук
        </a>
      </div>
      
      <p style="font-size: 14px; color: #666;">Це займе лише хвилинку</p>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <h4>📝 Що ми хотіли б знати:</h4>
      <ul>
        <li>Як ви оцінюєте якість обслуговування?</li>
        <li>Чи задоволені ви швидкістю роботи?</li>
        <li>Чи порекомендуєте нас друзям?</li>
      </ul>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>З повагою,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  {
    name: 'Запрос отзыва',
    template_type: 'review_request',
    language: 'ru',
    subject: 'Поделитесь впечатлениями об обслуживании',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Здравствуйте, {client_name}!</h2>
    
    <p>Спасибо за посещение <strong>{service_point_name}</strong>!</p>
    
    <div style="background: #fff3cd; padding: 20px; border-radius: 5px; margin: 20px 0; text-align: center;">
      <h3 style="color: #856404; margin-top: 0;">⭐ ПОДЕЛИТЕСЬ ВПЕЧАТЛЕНИЯМИ</h3>
      <p>Ваше мнение помогает нам становиться лучше!</p>
      
      <div style="margin: 20px 0;">
        <a href="{website_url}/reviews/new?booking_id={booking_id}" style="background: #ff9800; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold; font-size: 16px;">
          ⭐ Оставить отзыв
        </a>
      </div>
      
      <p style="font-size: 14px; color: #666;">Это займет всего минуту</p>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
      <h4>📝 Что мы хотели бы знать:</h4>
      <ul>
        <li>Как вы оцениваете качество обслуживания?</li>
        <li>Довольны ли вы скоростью работы?</li>
        <li>Порекомендуете ли нас друзьям?</li>
      </ul>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>С уважением,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  # 7. ПРИВЕТСТВИЕ НОВОГО ПОЛЬЗОВАТЕЛЯ
  {
    name: 'Вітання нового користувача',
    template_type: 'user_welcome',
    language: 'uk',
    subject: 'Ласкаво просимо до {company_name}!',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="text-align: center; margin-bottom: 30px;">
      <h1 style="color: #2c5aa0; margin-bottom: 10px;">Вітаємо, {client_name}!</h1>
      <h2 style="color: #666; font-weight: normal;">🎉 Дякуємо за реєстрацію в {company_name}!</h2>
    </div>
    
    <div style="background: #e8f5e8; padding: 20px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #2e7d32; margin-top: 0;">🏢 ТЕПЕР ВИ МАЄТЕ ДОСТУП ДО:</h3>
      <ul>
        <li>Онлайн бронювання послуг шиномонтажу</li>
        <li>Перегляду історії ваших записів</li>
        <li>Управління профілем та автомобілями</li>
        <li>Отримання нагадувань про записи</li>
        <li>Залишення відгуків про обслуговування</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="{website_url}/client/booking" style="background: #2c5aa0; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold; font-size: 16px;">
        📅 Створити перше бронювання
      </a>
    </div>
    
    <div style="background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #1565c0;">💡 КОРИСНІ ПОРАДИ:</h4>
      <ul>
        <li>Заповніть профіль та додайте інформацію про ваш автомобіль</li>
        <li>Підпишіться на нагадування, щоб не пропустити запис</li>
        <li>Зберігайте контакти наших сервісних точок</li>
      </ul>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4>📞 ПОТРІБНА ДОПОМОГА?</h4>
      <p>Наша служба підтримки завжди готова допомогти:</p>
      <ul style="list-style: none; padding: 0;">
        <li><strong>Email:</strong> <a href="mailto:{support_email}" style="color: #2c5aa0;">{support_email}</a></li>
        <li><strong>Телефон:</strong> {support_phone}</li>
      </ul>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>З повагою,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  {
    name: 'Приветствие нового пользователя',
    template_type: 'user_welcome',
    language: 'ru',
    subject: 'Добро пожаловать в {company_name}!',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="text-align: center; margin-bottom: 30px;">
      <h1 style="color: #2c5aa0; margin-bottom: 10px;">Здравствуйте, {client_name}!</h1>
      <h2 style="color: #666; font-weight: normal;">🎉 Спасибо за регистрацию в {company_name}!</h2>
    </div>
    
    <div style="background: #e8f5e8; padding: 20px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #2e7d32; margin-top: 0;">🏢 ТЕПЕРЬ У ВАС ЕСТЬ ДОСТУП К:</h3>
      <ul>
        <li>Онлайн бронированию услуг шиномонтажа</li>
        <li>Просмотру истории ваших записей</li>
        <li>Управлению профилем и автомобилями</li>
        <li>Получению напоминаний о записях</li>
        <li>Оставлению отзывов об обслуживании</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="{website_url}/client/booking" style="background: #2c5aa0; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold; font-size: 16px;">
        📅 Создать первое бронирование
      </a>
    </div>
    
    <div style="background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #1565c0;">💡 ПОЛЕЗНЫЕ СОВЕТЫ:</h4>
      <ul>
        <li>Заполните профиль и добавьте информацию о вашем автомобиле</li>
        <li>Подпишитесь на напоминания, чтобы не пропустить запись</li>
        <li>Сохраните контакты наших сервисных точек</li>
      </ul>
    </div>
    
    <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4>📞 НУЖНА ПОМОЩЬ?</h4>
      <p>Наша служба поддержки всегда готова помочь:</p>
      <ul style="list-style: none; padding: 0;">
        <li><strong>Email:</strong> <a href="mailto:{support_email}" style="color: #2c5aa0;">{support_email}</a></li>
        <li><strong>Телефон:</strong> {support_phone}</li>
      </ul>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>С уважением,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  # 8. ИНФОРМАЦИОННАЯ РАССЫЛКА
  {
    name: 'Інформаційна розсилка',
    template_type: 'newsletter',
    language: 'uk',
    subject: 'Новини від {company_name}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Вітаємо, {client_name}!</h2>
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #1565c0; margin-top: 0;">📰 НОВИНИ ТА АКЦІЇ ВІД {company_name}</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0;">
      {newsletter_content}
    </div>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #856404;">🎯 СПЕЦІАЛЬНА ПРОПОЗИЦІЯ</h4>
      {current_promotion}
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="{website_url}" style="background: #2c5aa0; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">
        🌐 Відвідати сайт
      </a>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>З повагою,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
      
      <p style="margin-top: 20px; font-size: 12px;">
        Якщо ви не хочете отримувати розсилку, <a href="{unsubscribe_url}" style="color: #666;">відпишіться тут</a>
      </p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  },

  {
    name: 'Информационная рассылка',
    template_type: 'newsletter',
    language: 'ru',
    subject: 'Новости от {company_name}',
    body: %{
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c5aa0;">Здравствуйте, {client_name}!</h2>
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #1565c0; margin-top: 0;">📰 НОВОСТИ И АКЦИИ ОТ {company_name}</h3>
    </div>
    
    <div style="background: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0;">
      {newsletter_content}
    </div>
    
    <div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h4 style="color: #856404;">🎯 СПЕЦИАЛЬНОЕ ПРЕДЛОЖЕНИЕ</h4>
      {current_promotion}
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="{website_url}" style="background: #2c5aa0; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">
        🌐 Посетить сайт
      </a>
    </div>
    
    <hr style="border: none; height: 1px; background: #ddd; margin: 30px 0;">
    
    <div style="text-align: center; color: #666; font-size: 14px;">
      <p>С уважением,<br>
      Команда <strong>{company_name}</strong><br>
      🌐 <a href="{website_url}" style="color: #2c5aa0;">{website_url}</a></p>
      
      <p style="margin-top: 20px; font-size: 12px;">
        Если вы не хотите получать рассылку, <a href="{unsubscribe_url}" style="color: #666;">отпишитесь здесь</a>
      </p>
    </div>
  </div>
</body>
</html>
    }.strip,
    is_active: true
  }
]

# Создаем шаблоны
puts ''
puts 'Создаем основные шаблоны...'

essential_templates.each_with_index do |template_data, index|
  begin
    template = EmailTemplate.create!(template_data)
    puts "#{index + 1}. ✅ #{template.name} (#{template.template_type}/#{template.language})"
  rescue ActiveRecord::RecordInvalid => e
    puts "#{index + 1}. ❌ Ошибка: #{template_data[:name]} - #{e.message}"
  rescue => e
    puts "#{index + 1}. ❌ Неожиданная ошибка: #{e.message}"
  end
end

puts ''
puts '📊 СТАТИСТИКА:'
puts "Всего шаблонов в БД: #{EmailTemplate.count}"
puts "Активных шаблонов: #{EmailTemplate.active.count}"
puts "Украинских шаблонов: #{EmailTemplate.where(language: 'uk').count}"
puts "Русских шаблонов: #{EmailTemplate.where(language: 'ru').count}"

puts ''
puts 'Типы шаблонов:'
EmailTemplate.distinct.pluck(:template_type).each do |type|
  count = EmailTemplate.where(template_type: type).count
  puts "- #{type}: #{count} шт."
end

puts ''
puts '✅ СОЗДАНИЕ ОСНОВНЫХ EMAIL ШАБЛОНОВ ЗАВЕРШЕНО!'
puts '🎯 Все шаблоны имеют HTML разметку для лучшей читаемости'
puts '🔒 Валидация уникальности предотвращает дубли'
puts '📧 Готово к отправке писем!' 
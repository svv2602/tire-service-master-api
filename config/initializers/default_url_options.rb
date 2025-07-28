Rails.application.routes.default_url_options = {
  host:     ENV.fetch('APP_HOST', 'service-station.tot.biz.ua'),
  protocol: 'http'                           # если нужен https
}

# то же для mailer’ов и фоновых задач
Rails.application.config.action_controller.default_url_options =
  Rails.application.routes.default_url_options
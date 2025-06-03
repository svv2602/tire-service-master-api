# Включаем методы гема в контроллер
require 'pagy/extras/metadata'
require 'pagy/extras/array' # Для работы с массивами
require 'pagy/extras/headers' # для добавления информации о пагинации в заголовки

# Конфигурация
Pagy::DEFAULT[:limit] = 20        # По умолчанию 20 элементов на странице (используем :limit вместо :items)
Pagy::DEFAULT[:max_items] = 100   # Максимально 100 элементов на странице
Pagy::DEFAULT[:size] = [1, 3, 3, 1] # Количество показываемых номеров страниц
Pagy::DEFAULT[:page_param] = :page # Имя параметра страницы
Pagy::DEFAULT[:items_param] = :per_page # Имя параметра количества элементов

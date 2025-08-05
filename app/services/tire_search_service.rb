class TireSearchService
  # Константы алиасов для брендов
  BRAND_ALIASES = {
    ['bmw', 'бмв', 'бэмв', 'бмдабльвэ'] => 'BMW',
    ['volkswagen', 'vw', 'фольксваген', 'фольскваген', 'фольц', 'вольксваген'] => 'Volkswagen',
    ['mercedes', 'мерседес', 'мерс', 'mercedes-benz', 'мерседес-бенц'] => 'Mercedes',
    ['toyota', 'тойота'] => 'Toyota',
    ['honda', 'хонда'] => 'Honda',
    ['audi', 'ауди'] => 'Audi',
    ['ford', 'форд'] => 'Ford',
    ['opel', 'опель'] => 'Opel',
    ['renault', 'рено'] => 'Renault',
    ['peugeot', 'пежо'] => 'Peugeot',
    ['citroen', 'ситроен'] => 'Citroen',
    ['nissan', 'ниссан'] => 'Nissan',
    ['mazda', 'мазда'] => 'Mazda',
    ['hyundai', 'хундай', 'хёндай'] => 'Hyundai',
    ['kia', 'киа'] => 'Kia',
    ['skoda', 'шкода'] => 'Skoda',
    ['seat', 'сеат'] => 'SEAT',
    ['fiat', 'фиат'] => 'Fiat',
    ['volvo', 'вольво'] => 'Volvo',
    ['mitsubishi', 'митсубиси'] => 'Mitsubishi',
    ['tesla', 'тесла', 'теслу'] => 'Tesla',
    ['brilliance', 'бриллианс', 'брилансе', 'брилианс', 'бриланс'] => 'Brilliance',
    # ТОП бренды по конфигурациям шин
    ['chevrolet', 'шевроле', 'шеви'] => 'Chevrolet',
    ['dongfeng', 'донгфенг'] => 'Dongfeng',
    ['chery', 'чери'] => 'Chery',
    ['daihatsu', 'дайхатцу'] => 'Daihatsu',
    ['suzuki', 'сузуки'] => 'Suzuki',
    ['geely', 'джили'] => 'Geely',
    ['ferrari', 'феррари'] => 'Ferrari',
    ['jac'] => 'JAC',
    ['faw'] => 'FAW'
  }.freeze

  # Константы производителей шин (топ-100)
  TIRE_BRANDS = [
    'Michelin', 'Bridgestone', 'Continental', 'Pirelli', 'Goodyear', 'Dunlop', 'Yokohama',
    'Hankook', 'Kumho', 'Toyo', 'Falken', 'Nokian', 'Cooper', 'BFGoodrich', 'Uniroyal',
    'General', 'Maxxis', 'Nitto', 'Nexen', 'GT Radial', 'Achilles', 'Accelera', 'Federal',
    'Nankang', 'Linglong', 'Triangle', 'Roadstone', 'Matador', 'Barum', 'Sava', 'Vredestein',
    'Semperit', 'Gislaved', 'Cordiant', 'Kama', 'Viatti', 'Амтел', 'Белшина', 'Росава'
  ].freeze

  # Алиасы производителей шин
  TIRE_BRAND_ALIASES = {
    ['michelin', 'мишлен', 'мишелин'] => 'Michelin',
    ['bridgestone', 'бриджстоун', 'бриджстон'] => 'Bridgestone',
    ['continental', 'континенталь', 'конти'] => 'Continental',
    ['pirelli', 'пирелли'] => 'Pirelli',
    ['goodyear', 'гудьир', 'гудиер'] => 'Goodyear',
    ['dunlop', 'данлоп'] => 'Dunlop',
    ['yokohama', 'йокохама'] => 'Yokohama',
    ['hankook', 'ханкок'] => 'Hankook',
    ['kumho', 'кумхо'] => 'Kumho',
    ['nokian', 'нокиан'] => 'Nokian',
    ['cooper', 'купер'] => 'Cooper',
    ['toyo', 'тойо'] => 'Toyo',
    ['falken', 'фалькен'] => 'Falken'
  }.freeze

  # Константы сезонности
  SEASONALITY_ALIASES = {
    # Зимние шины - русский и украинский
    ['зимние', 'зима', 'зимняя', 'зимних', 'зимой', 'winter', 'зимняя резина', 'snow',
     'зимові', 'зимова', 'зимовые', 'взимку', 'зимові шини'] => 'winter',
    
    # Летние шины - русский и украинский  
    ['летние', 'лето', 'летняя', 'летних', 'летом', 'summer', 'летняя резина',
     'літні', 'літо', 'літня', 'влітку', 'літні шини'] => 'summer',
     
    # Всесезонные шины - русский и украинский
    ['всесезонные', 'всесезон', 'всесезонная', 'всесезонка', 'круглогодичные', 'круглый год',
     'all season', 'all-season', 'всесезонная резина',
     'всесезонні', 'цілорічні', 'всесезонна', 'всесезонні шини'] => 'all_season'
  }.freeze

  # Константы алиасов для моделей по брендам
  MODEL_ALIASES = {
    'BMW' => {
      ['3', '320', '320i', '320d', '320cdi', '325', '325i', '330', '330i', '330d', 'тройка', '3 series', 'третья серия'] => '3 Series',
      ['5', '520', '520i', '520d', '525', '525i', '530', '530i', '530d', 'пятерка', '5 series', 'пятая серия'] => '5 Series',
      ['7', '730', '730i', '730d', '740', '740i', '740d', 'семерка', '7 series', 'седьмая серия'] => '7 Series',
      ['x3', 'икс3', 'x 3', 'x3 20i', 'x3 20d', 'x3 25i', 'x3 30i'] => 'X3',
      ['x5', 'икс5', 'x 5', 'x5 25i', 'x5 30i', 'x5 35i', 'x5 40i'] => 'X5',
      ['x1', 'икс1', 'x 1', 'x1 18i', 'x1 20i', 'x1 25i'] => 'X1'
    },
    'Volkswagen' => {
      ['tiguan', 'тигуан'] => 'Tiguan',
      ['golf', 'гольф'] => 'Golf',
      ['passat', 'пассат'] => 'Passat',
      ['polo', 'поло'] => 'Polo',
      ['touareg', 'туарег'] => 'Touareg',
      ['jetta', 'джетта'] => 'Jetta'
    },
    'Mercedes' => {
      # A-Class (порядок важен: специфичные варианты сначала)
      ['a class amg', 'a-class amg', 'а класс amg'] => 'A-Class AMG',
      ['a class', 'a-class', 'а класс', 'a200', 'a180'] => 'A-Class',
      ['a class w168', 'a-class w168'] => 'A-Class W168',
      ['a class w169', 'a-class w169'] => 'A-Class W169',
      ['a class w176', 'a-class w176'] => 'A-Class W176',
      
      # B-Class
      ['b class', 'b-class', 'б класс', 'b200', 'b180'] => 'B-Class',
      ['b class w245', 'b-class w245'] => 'B-Class W245',
      ['b class w246', 'b-class w246'] => 'B-Class W246',
      
      # C-Class
      ['c class amg', 'c-class amg', 'с класс amg'] => 'C-Class AMG',
      ['c class', 'c-class', 'с класс', 'c200', 'c220', 'c300'] => 'C-Class',
      ['c class w202', 'c-class w202'] => 'C-Class W202 S202',
      ['c class w203', 'c-class w203'] => 'C-Class W203 CL203 S203',
      ['c class w204', 'c-class w204'] => 'C-Class W204 S204',
      ['c class w205', 'c-class w205'] => 'C-Class W205',
      
      # E-Class
      ['e class amg', 'e-class amg', 'е класс amg'] => 'E-Class AMG',
      ['e class', 'e-class', 'е класс', 'e200', 'e220', 'e300'] => 'E-Class',
      ['e class cabriolet', 'e-class cabriolet'] => 'E-Class Cabriolet',
      ['e class coupe', 'e-class coupe'] => 'E-Class Coupe',
      ['e class all-terrain', 'e-class all terrain'] => 'E-Class All-Terrain',
      ['e class w210', 'e-class w210'] => 'E-Class W210 S210',
      ['e class w211', 'e-class w211'] => 'E-Class W211 S211',
      ['e class w212', 'e-class w212'] => 'E-Class W212 S212',
      ['e class w213', 'e-class w213'] => 'E-Class W213 C207',
      
      # S-Class
      ['s class cabrio amg', 's-class cabrio amg'] => 'S-Class Cabrio AMG',
      ['s class coupe amg', 's-class coupe amg'] => 'S-Class Coupe AMG',
      ['s class amg', 's-class amg', 'с класс amg'] => 'S-Class AMG',
      ['s class cabrio', 's-class cabrio'] => 'S-Class Cabrio',
      ['s class coupe', 's-class coupe'] => 'S-Class Coupe',
      ['s class', 's-class', 'с класс', 's500', 's400', 's600'] => 'S-Class',
      ['s class w140', 's-class w140'] => 'S-Class W140 C140',
      ['s class w220', 's-class w220'] => 'S-Class W220',
      ['s class w221', 's-class w221'] => 'S-Class W221',
      ['s class w222', 's-class w222'] => 'S-Class W222',
      
      # GLC
      ['glc coupe amg', 'glc-class coupe amg'] => 'GLC-Class Coupe AMG',
      ['glc amg', 'glc-class amg'] => 'GLC-Class AMG',
      ['glc coupe', 'glc-class coupe'] => 'GLC-Class Coupe',
      ['glc', 'глс', 'glc class', 'glc-class'] => 'GLC-Class',
      ['glc x253', 'glc-class x253'] => 'GLC-ClassX253',
      
      # GLE  
      ['gle coupe amg', 'gle-class coupe amg'] => 'GLE-Class Coupe AMG',
      ['gle class amg', 'gle-class amg'] => 'GLE-Class AMG',
      ['gle amg'] => 'GLE AMG',
      ['gle coupe', 'gle-class coupe'] => 'GLE-Class Coupe',
      ['gle', 'гле', 'gle class', 'gle-class'] => 'GLE-Class',
      ['gle w166', 'gle-class w166'] => 'GLE-ClassW166',
      ['gle coupe c292'] => 'GLE CoupeC292',
      
      # GLA
      ['gla', 'gla class', 'gla-class'] => 'GLA-Class',
      ['gla amg', 'gla-class amg'] => 'GLA-Class AMG',
      ['gla x156', 'gla-class x156'] => 'GLA-Class X156',
      
      # GLB
      ['glb', 'glb class', 'glb-class'] => 'GLB-Class',
      ['glb amg', 'glb-class amg'] => 'GLB-Class AMG',
      
      # GLS
      ['gls', 'gls class', 'gls-class'] => 'GLS-Class',
      ['gls amg', 'gls-class amg'] => 'GLS-Class AMG',
      
      # GL-Class (старая линейка)
      ['gl class', 'gl-class'] => 'GL-Class',
      ['gl class amg', 'gl-class amg'] => 'GL-Class AMG',
      ['gl x164', 'gl-class x164'] => 'GL-Class X164',
      ['gl x166', 'gl-class x166'] => 'GL-Class X166',
      
      # GLK
      ['glk', 'glk class', 'glk-class'] => 'GLK-Class',
      ['glk x204', 'glk-class x204'] => 'GLK-Class X204',
      
      # M-Class (старая линейка, сейчас GLE)
      ['m class', 'm-class'] => 'M-Class',
      ['m class amg', 'm-class amg'] => 'M-Class AMG',
      ['m class w163', 'm-class w163'] => 'M-Class W163',
      ['m class w164', 'm-class w164'] => 'M-Class W164',
      ['m class w166', 'm-class w166'] => 'M-Class W166',
      
      # G-Class
      ['g class', 'g-class', 'g wagon', 'g вагон', 'гелендваген'] => 'G-Class',
      ['g class amg', 'g-class amg'] => 'G-Class AMG',
      ['g class w463', 'g-class w463'] => 'G-Class W463',
      
      # CLA
      ['cla', 'cla class', 'cla-class'] => 'CLA-Class',
      ['cla amg', 'cla-class amg'] => 'CLA-Class AMG',
      ['cla c117', 'cla-class c117'] => 'CLA-Class C117',
      
      # CLS
      ['cls', 'cls class', 'cls-class'] => 'CLS-Class',
      ['cls amg', 'cls-class amg'] => 'CLS-Class AMG',
      ['cls c218', 'cls-class c218'] => 'CLS-Class C218 X218',
      ['cls c219', 'cls-class c219'] => 'CLS-Class C219',
      
      # CL-Class
      ['cl class', 'cl-class'] => 'CL-Class',
      ['cl class amg', 'cl-class amg'] => 'CL-Class AMG',
      ['cl c215', 'cl-class c215'] => 'CL-Class C215',
      ['cl c216', 'cl-class c216'] => 'CL-Class C216',
      
      # CLK
      ['clk', 'clk class', 'clk-class'] => 'CLK-Class',
      ['clk amg', 'clk-class amg'] => 'CLK-Class AMG',
      ['clk c208', 'clk-class c208'] => 'CLK-Class C208 A208',
      ['clk c209', 'clk-class c209'] => 'CLK-Class C209 A209',
      
      # CLC
      ['clc', 'clc class', 'clc-class'] => 'CLC-Class',
      
      # SL
      ['sl', 'sl class', 'sl-class'] => 'SL-Class',
      ['sl amg', 'sl-class amg'] => 'SL-Class AMG',
      ['sl r230', 'sl-class r230'] => 'SL-Class R230',
      ['sl r231', 'sl-class r231'] => 'SL-Class R231',
      
      # SLK
      ['slk', 'slk class', 'slk-class'] => 'SLK-Class',
      ['slk amg', 'slk-class amg'] => 'SLK-Class AMG',
      ['slk r170', 'slk-class r170'] => 'SLK-Class R170',
      ['slk r171', 'slk-class r171'] => 'SLK-Class R171',
      ['slk r172', 'slk-class r172'] => 'SLK-Class R172',
      
      # SLC
      ['slc', 'slc class', 'slc-class'] => 'SLC-Class',
      ['slc amg', 'slc-class amg'] => 'SLC-Class AMG',
      
      # SLR
      ['slr', 'slr class', 'slr-class'] => 'SLR-Class',
      ['slr r199', 'slr-class r199'] => 'SLR-Class R199',
      
      # SLS
      ['sls', 'sls class', 'sls-class'] => 'SLS-Class AMG',
      ['sls amg', 'sls-class amg'] => 'SLS-Class AMG',
      ['sls a197', 'sls amg a197'] => 'SLS AMG A197 C197',
      
      # AMG GT
      ['amg gt', 'gt amg'] => 'AMG GT',
      ['amg gt-4', 'gt-4 amg'] => 'AMG GT-4',
      
      # R-Class
      ['r class', 'r-class'] => 'R-Class',
      ['r class amg', 'r-class amg'] => 'R-Class AMG',
      ['r class w251', 'r-class w251'] => 'R-Class W251',
      
      # V-Class / Viano
      ['v class', 'v-class'] => 'V-Class',
      ['v class w447', 'v-class w447'] => 'V-Class W447',
      ['viano', 'виано'] => 'Viano',
      ['viano w639'] => 'Viano W639',
      
      # Vito
      ['vito', 'вито'] => 'Vito',
      ['vito w638'] => 'Vito W638',
      
      # Sprinter
      ['sprinter', 'спринтер'] => 'Sprinter',
      
      # Citan
      ['citan', 'цитан'] => 'Citan',
      
      # Metris
      ['metris', 'метрис'] => 'Metris',
      
      # Marco Polo
      ['marco polo', 'марко поло'] => 'Marco Polo',
      
      # T-Class
      ['t class', 't-class'] => 'T-Class',
      
      # X-Class
      ['x class', 'x-class'] => 'X-Class',
      
      # EQA/EQB/EQC/EQE/EQS (электромобили)
      ['eqa'] => 'EQA',
      ['eqb'] => 'EQB', 
      ['eqc'] => 'EQC',
      ['eqe'] => 'EQE',
      ['eqe amg'] => 'EQE AMG',
      ['eqs'] => 'EQS',
      ['eqs amg'] => 'EQS AMG',
      ['eqt'] => 'EQT',
      ['eqv'] => 'EQV',
      
      # Старые модели
      ['190', 'w201'] => '190',
      ['w123'] => 'W123',
      ['w124'] => 'W124',
      ['vaneo', 'ванео'] => 'Vaneo',
      ['vaneo w414'] => 'Vaneo W414',
      ['t1'] => 'T1',
      ['t2'] => 'T2'
    },
    'Toyota' => {
      ['camry', 'камри'] => 'Camry',
      ['corolla', 'корола'] => 'Corolla',
      ['rav4', 'рав4', 'rav 4'] => 'RAV4',
      ['land cruiser', 'ленд крузер', 'крузер'] => 'Land Cruiser',
      ['prius', 'приус'] => 'Prius'
    },
    'Honda' => {
      ['civic', 'цивик'] => 'Civic',
      ['accord', 'аккорд'] => 'Accord',
      ['cr-v', 'crv', 'цр-в'] => 'CR-V'
    },
    'Renault' => {
      ['logan', 'логан'] => 'Logan',
      ['duster', 'дастер'] => 'Duster',
      ['sandero', 'сандеро'] => 'Sandero',
      ['megane', 'меган'] => 'Megane',
      ['fluence', 'флюенс'] => 'Fluence',
      ['kaptur', 'каптур'] => 'Kaptur',
      ['koleos', 'колеос'] => 'Koleos',
      ['laguna', 'лагуна'] => 'Laguna',
      ['dokker', 'доккер', 'докер'] => 'Dokker'
    },
    'Audi' => {
      ['a3', 'а3'] => 'A3',
      ['a4', 'а4'] => 'A4',
      ['a6', 'а6'] => 'A6',
      ['q3', 'ку3'] => 'Q3',
      ['q5', 'ку5'] => 'Q5',
      ['q7', 'ку7'] => 'Q7'
    },
    'Ford' => {
      ['focus', 'фокус'] => 'Focus',
      ['mondeo', 'мондео'] => 'Mondeo',
      ['fiesta', 'фиеста'] => 'Fiesta',
      ['kuga', 'куга'] => 'Kuga',
      ['explorer', 'эксплорер'] => 'Explorer'
    },
    'Hyundai' => {
      ['solaris', 'солярис'] => 'Solaris',
      ['elantra', 'элантра'] => 'Elantra',
      ['tucson', 'туксон'] => 'Tucson',
      ['santa fe', 'санта фе'] => 'Santa Fe',
      ['creta', 'крета'] => 'Creta'
    },
    'Kia' => {
      ['rio', 'рио'] => 'Rio',
      ['cerato', 'церато'] => 'Cerato',
      ['sportage', 'спортейдж'] => 'Sportage',
      ['sorento', 'соренто'] => 'Sorento',
      ['picanto', 'пиканто'] => 'Picanto'
    },
    'Tesla' => {
      ['model 3', 'модель 3', 'третья модель'] => 'Model 3',
      ['model s', 'модель s', 'модель с'] => 'Model S', 
      ['model x', 'модель x', 'модель икс'] => 'Model X',
      ['model y', 'модель y', 'модель игрек'] => 'Model Y',
      ['roadster', 'родстер'] => 'Roadster'
    },
    'Mazda' => {
      ['2', 'мазда 2'] => '2',
      ['3', 'мазда 3'] => '3',
      ['6', 'мазда 6'] => '6',
      ['cx-3', 'cx3'] => 'CX-3',
      ['cx-5', 'cx5'] => 'CX-5',
      ['cx-7', 'cx7'] => 'CX-7',
      ['cx-9', 'cx9'] => 'CX-9',
      ['mx-5', 'mx5', 'miata'] => 'MX-5'
    },
    'Brilliance' => {
      ['h530', '530'] => 'H530',
      ['h330', '330'] => 'H330',
      ['h220', '220'] => 'H220',
      ['h320', '320'] => 'H320',
      ['bs4', 'v4'] => 'BS4',
      ['bs6', 'v6'] => 'BS6',
      ['v3'] => 'V3',
      ['v5'] => 'V5'
    }
  }.freeze

  def initialize(query, options = {})
    @query = query.to_s.strip
    @options = options
    @parsed_data = {}
    @use_llm = options[:use_llm] != false
    @locale = options[:locale] || 'ru'
    
    # Контекст из предыдущих шагов диалога
    @context = options[:context] || {}
    Rails.logger.info "TireSearchService: Initialized with locale: #{@locale}, context: #{@context}"
  end

  def search
    return build_empty_response if @query.blank?

    # Шаг 1: Простой парсинг
    @parsed_data = parse_simple_query
    
    # Шаг 1.5: Объединяем с контекстом из предыдущих шагов диалога
    merge_with_context

    # Шаг 2: Если простой парсинг неполный и включен LLM - используем LLM
    @llm_was_used = false
    if needs_llm_parsing? && @use_llm
      @llm_was_used = true
      llm_result = parse_with_llm
      if llm_result.present?
        # LLM может исправлять результаты простого парсинга если они неточные
        # Приоритет: LLM перезаписывает простой парсинг для brand и model
        @parsed_data = smart_merge_results(@parsed_data, llm_result)
      end
    end

    # Шаг 3: Определяем сценарий поиска и обрабатываем
    response = process_search_scenario

    response
  end

  private

  def build_empty_response
    {
      success: false,
      message: "Запрос не может быть пустым",
      tire_sizes: [],
      tire_brands: [],
      seasonality: nil,
      car_info: {},
      query: @query,
      parsed_data: {},
      suggestions: generate_suggestions
    }
  end

  def process_search_scenario
    car_identified = @parsed_data[:brand].present? && @parsed_data[:model].present?
    brand_with_diameter = @parsed_data[:brand].present? && @parsed_data[:model].blank? && @parsed_data[:diameter].present?
    full_tire_size = @parsed_data[:width].present? && @parsed_data[:height].present? && @parsed_data[:diameter].present?
    

    
    # Если LLM использовался, но не смог распарсить бренд (например: "лада на 14") - переходим в диалог
    # НО исключаем случаи, когда у нас есть полный размер шины
    if @llm_was_used && @parsed_data[:brand].blank? && @parsed_data[:diameter].present? && !full_tire_size
      Rails.logger.info "LLM использовался, но не распарсил бренд для запроса '#{@query}' - переходим в conversational режим"
      return process_insufficient_data_scenario
    end
    
    # ПРИОРИТЕТ: Если распарсен полный размер шин (ширина + высота + диаметр), 
    # то игнорируем автомобиль и ищем сразу по размеру
    if @parsed_data[:tire_size].present? || full_tire_size
      Rails.logger.info "TireSearchService: Найден полный размер шин, игнорируем автомобиль и переходим к поиску по размеру"
      process_tire_size_only_scenario
    elsif car_identified
      # Сценарии 1-3: Автомобиль определен (только если НЕТ полного размера)
      process_car_identified_scenario
    elsif brand_with_diameter
      # Бренд + диаметр без модели - запрос уточнения модели
      process_brand_diameter_scenario
    elsif @parsed_data[:diameter].present? ||
          (@parsed_data[:width].present? && @parsed_data[:height].present?) ||
          (@parsed_data[:width].present? && @parsed_data[:diameter].present()) ||
          (@parsed_data[:height].present? && @parsed_data[:diameter].present?)
      # Есть размер шин (частичный), но авто не определено
      process_tire_size_only_scenario
    else
      # Недостаточно данных
      process_insufficient_data_scenario
    end
  end

  def process_car_identified_scenario
    # Поиск размеров для определенного автомобиля
    car_configurations = find_car_configurations
    
    if car_configurations.empty?
      # Проверяем существует ли автомобиль в нашей БД брендов/моделей
      car_exists = car_exists_in_database?(@parsed_data[:brand], @parsed_data[:model])
      
      message = if car_exists
        "Для #{@parsed_data[:brand]} #{@parsed_data[:model]} пока нет данных о размерах шин. Уточните год выпуска или укажите размер шин напрямую (например: 205/55R16)."
      else
        "Уточните свой запрос - недостаточно данных для поиска или укажите размер шин напрямую (например: 205/55R16)."
      end
      
      return {
        success: false,
        message: message,
        tire_sizes: [],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: extract_car_info,
        query: @query,
        parsed_data: @parsed_data,
        suggestions: generate_car_suggestions
      }
    end

    # Извлекаем размеры шин для автомобиля
    tire_sizes = extract_tire_sizes_from_configurations(car_configurations)
    
    # Фильтруем по диаметру если указан
    if @parsed_data[:diameter].present?
      tire_sizes = tire_sizes.select { |size| size[:diameter] == @parsed_data[:diameter] }
    end

    # Проверяем указанный размер шин
    validation_result = validate_tire_size_for_car(tire_sizes)

    {
      success: true,
      message: validation_result[:message],
      tire_sizes: validation_result[:tire_sizes],
      tire_brands: @parsed_data[:tire_brands] || [],
      seasonality: @parsed_data[:seasonality],
      car_info: extract_car_info,
      query: @query,
      parsed_data: @parsed_data,
      warnings: validation_result[:warnings] || []
    }
  end

  def process_tire_size_only_scenario
    # Указан размер шин, но автомобиль не определен
    tire_sizes = []
    message = ""
    
    if @parsed_data[:tire_size].present?
      tire_sizes << @parsed_data[:tire_size]
      message = "Найден размер шин, но автомобиль не определен. Рекомендуем указать марку и модель для более точного подбора."
    elsif @parsed_data[:width].present? && @parsed_data[:height].present? && @parsed_data[:diameter].present?
      tire_sizes << {
        width: @parsed_data[:width],
        height: @parsed_data[:height],
        diameter: @parsed_data[:diameter]
      }
      message = "Найден размер шин, но автомобиль не определен. Рекомендуем указать марку и модель для более точного подбора."
    elsif @parsed_data[:width].present? && @parsed_data[:height].present?
      # Случай: ширина + высота без диаметра (например "175 70")
      message = I18n.with_locale(@locale) do
        I18n.t('tire_search.messages.width_height_only', 
               width: @parsed_data[:width], 
               height: @parsed_data[:height])
      end
      
      return {
        success: false,
        conversation_mode: true,
        message: message,
        tire_sizes: [{
          width: @parsed_data[:width],
          height: @parsed_data[:height],
          display: "#{@parsed_data[:width]}/#{@parsed_data[:height]}R?"
        }],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: {},
        query: @query,
        parsed_data: @parsed_data,
        suggestions: generate_car_brand_suggestions,
        follow_up_questions: [{
          type: "partial_size_completion",
          width: @parsed_data[:width],
          height: @parsed_data[:height],
          field: "diameter"
        }],
        context: {
          width: @parsed_data[:width],
          height: @parsed_data[:height],
          tire_brands: @parsed_data[:tire_brands],
          seasonality: @parsed_data[:seasonality]
        }.compact
      }
    elsif @parsed_data[:width].present? && @parsed_data[:diameter].present?
      # Случай: ширина + диаметр без высоты (например "215 на 16")
      message = I18n.with_locale(@locale) do
        I18n.t('tire_search.messages.width_diameter_only', 
               width: @parsed_data[:width], 
               diameter: @parsed_data[:diameter])
      end
      
      return {
        success: false,
        conversation_mode: true,
        message: message,
        tire_sizes: [{
          width: @parsed_data[:width],
          diameter: @parsed_data[:diameter],
          display: "#{@parsed_data[:width]}/?R#{@parsed_data[:diameter]}"
        }],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: {},
        query: @query,
        parsed_data: @parsed_data,
        suggestions: generate_car_brand_suggestions,
        follow_up_questions: [{
          type: "partial_size_completion",
          width: @parsed_data[:width],
          diameter: @parsed_data[:diameter],
          field: "height"
        }],
        context: {
          width: @parsed_data[:width],
          diameter: @parsed_data[:diameter],
          tire_brands: @parsed_data[:tire_brands],
          seasonality: @parsed_data[:seasonality]
        }.compact
      }
    elsif @parsed_data[:height].present? && @parsed_data[:diameter].present?
      # Случай: высота + диаметр без ширины (например "70 на 16")
      message = I18n.with_locale(@locale) do
        I18n.t('tire_search.messages.height_diameter_only', 
               height: @parsed_data[:height], 
               diameter: @parsed_data[:diameter])
      end
      
      return {
        success: false,
        conversation_mode: true,
        message: message,
        tire_sizes: [{
          height: @parsed_data[:height],
          diameter: @parsed_data[:diameter],
          display: "?/#{@parsed_data[:height]}R#{@parsed_data[:diameter]}"
        }],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: {},
        query: @query,
        parsed_data: @parsed_data,
        suggestions: generate_car_brand_suggestions,
        follow_up_questions: [{
          type: "partial_size_completion",
          height: @parsed_data[:height],
          diameter: @parsed_data[:diameter],
          field: "width"
        }],
        context: {
          height: @parsed_data[:height],
          diameter: @parsed_data[:diameter],
          tire_brands: @parsed_data[:tire_brands],
          seasonality: @parsed_data[:seasonality]
        }.compact
      }
    elsif @parsed_data[:diameter].present?
      # Случай когда найден только диаметр (например "R18")
      # Переходим в conversational режим для уточнения
      message = I18n.with_locale(@locale) do
        I18n.t('tire_search.messages.diameter_only', diameter: @parsed_data[:diameter])
      end
      
      return {
        success: false,
        conversation_mode: true,
        message: message,
        tire_sizes: [{
          diameter: @parsed_data[:diameter],
          display: "R#{@parsed_data[:diameter]}"
        }],
        tire_brands: @parsed_data[:tire_brands] || [],
        seasonality: @parsed_data[:seasonality],
        car_info: {},
        query: @query,
        parsed_data: @parsed_data,
        suggestions: generate_car_brand_suggestions,
        follow_up_questions: [{
          type: "partial_size_completion",
          diameter: @parsed_data[:diameter],
          field: "tire_size"
        }],
        # Контекст для следующего шага диалога
        context: {
          diameter: @parsed_data[:diameter],
          tire_brands: @parsed_data[:tire_brands],
          seasonality: @parsed_data[:seasonality]
        }.compact
      }
    end

    {
      success: true,
      message: message,
      tire_sizes: tire_sizes,
      tire_brands: @parsed_data[:tire_brands] || [],
      seasonality: @parsed_data[:seasonality],
      car_info: {},
      query: @query,
      parsed_data: @parsed_data,
      suggestions: generate_car_brand_suggestions
    }
  end

  def process_brand_diameter_scenario
    # Бренд найден, диаметр найден, но модель не указана
    # Нужно запросить уточнение модели с учетом диаметра
    
    message = I18n.with_locale(@locale) do
      I18n.t('tire_search.messages.brand_diameter_specify_model', 
             brand: @parsed_data[:brand], 
             diameter: @parsed_data[:diameter])
    end

    # Генерируем предложения моделей для данного бренда
    model_suggestions = []
    
    # Из алиасов
    if MODEL_ALIASES[@parsed_data[:brand]]
      MODEL_ALIASES[@parsed_data[:brand]].each do |aliases, model_name|
        model_suggestions << "#{@parsed_data[:brand]} #{model_name}"
      end
    end
    
    # Из БД (динамические модели)
    dynamic_models = find_models_for_brand(@parsed_data[:brand])
    dynamic_models.each do |model_name|
      suggestion = "#{@parsed_data[:brand]} #{model_name}"
      model_suggestions << suggestion unless model_suggestions.include?(suggestion)
    end
    
    # Ограничиваем количество предложений
    model_suggestions = model_suggestions.first(8)

    {
      success: false,
      conversation_mode: true,
      message: message,
      tire_sizes: [{
        diameter: @parsed_data[:diameter],
        display: "R#{@parsed_data[:diameter]}"
      }],
      tire_brands: @parsed_data[:tire_brands] || [],
      seasonality: @parsed_data[:seasonality],
      car_info: {
        brand: @parsed_data[:brand]
      },
      query: @query,
      parsed_data: @parsed_data,
      suggestions: model_suggestions,
      follow_up_questions: [{
        type: "model_selection",
        brand: @parsed_data[:brand],
        field: "model",
        diameter: @parsed_data[:diameter]
      }],
      # Контекст для следующего шага диалога
      context: {
        brand: @parsed_data[:brand],
        diameter: @parsed_data[:diameter],
        tire_brands: @parsed_data[:tire_brands],
        seasonality: @parsed_data[:seasonality]
      }.compact
    }
  end

  def process_insufficient_data_scenario
    # Проверяем, есть ли пользователь ввел что-то, что не распознано
    unrecognized_input = detect_unrecognized_input
    
    # Персонализируем сообщение в зависимости от того, что уже найдено
    message = if unrecognized_input
      "К сожалению, в нашей базе нет данных о #{unrecognized_input}. Попробуйте выбрать из предложенных вариантов или введите размер шин напрямую (например: 205/55R16)."
    elsif @parsed_data[:brand].present? && @parsed_data[:model].present?
      # Проверяем существует ли такой автомобиль в БД
      if car_exists_in_database?(@parsed_data[:brand], @parsed_data[:model])
        "Отлично! #{@parsed_data[:brand]} #{@parsed_data[:model]} - хороший выбор. Уточните модель для точного подбора шин:"
      else
        "Уточните свой запрос - недостаточно данных для поиска или укажите размер шин напрямую (например: 205/55R16)."
      end
    elsif @parsed_data[:brand].present? && @parsed_data[:model].blank?
      # Проверяем есть ли модели для этого бренда в нашей базе (через алиасы или БД)
      has_models = (MODEL_ALIASES[@parsed_data[:brand]] && MODEL_ALIASES[@parsed_data[:brand]].any?) || 
                   find_models_for_brand(@parsed_data[:brand]).any?
      
      if has_models
        message = I18n.with_locale(@locale) do
          I18n.t('tire_search.messages.excellent_choice', brand: @parsed_data[:brand])
        end
        Rails.logger.info "TireSearchService: Generated message with locale #{@locale}: #{message}"
        message
      else
        message = I18n.with_locale(@locale) do
          I18n.t('tire_search.messages.insufficient_data')
        end
        Rails.logger.info "TireSearchService: Generated message with locale #{@locale}: #{message}"
        message
      end
    elsif @parsed_data[:tire_brands].present? || @parsed_data[:seasonality].present?
      I18n.with_locale(@locale) do
        I18n.t('tire_search.messages.preferences_understood')
      end
    else
      I18n.with_locale(@locale) do
        I18n.t('tire_search.messages.help_select')
      end
    end

    {
      success: false,
      message: message,
      tire_sizes: [],
      tire_brands: @parsed_data[:tire_brands] || [],
      seasonality: @parsed_data[:seasonality],
      car_info: {},
      query: @query,
      parsed_data: @parsed_data,
      suggestions: unrecognized_input ? generate_alternative_suggestions : generate_suggestions,
      conversation_mode: true, # Флаг для фронтенда - показать режим уточнения
      follow_up_questions: unrecognized_input ? generate_alternative_questions : generate_follow_up_questions,
      warnings: unrecognized_input ? ["Автомобиль не найден в базе данных"] : nil
    }
  end

  def parse_simple_query
    result = {}
    query_lower = @query.downcase

    # Поиск полного размера шин (приоритет) - различные форматы
    # Формат 1: 225/50R17 (стандартный)
    tire_size_matches = @query.scan(/\b(\d{3})\/(\d{2})r(\d{2})\b/i)
    
    # Формат 2: 225/50/17 (со слэшами)
    if tire_size_matches.empty?
      tire_size_matches = @query.scan(/\b(\d{3})\/(\d{2})\/(\d{2})\b/)
    end
    
    # Формат 3: 175 70 13 (через пробелы)
    if tire_size_matches.empty?
      space_matches = @query.scan(/\b(\d{3})\s+(\d{2})\s+(\d{2})\b/)
      tire_size_matches = space_matches if space_matches.any?
    end
    
    # Формат 4: 175-70-13 (через дефисы)
    if tire_size_matches.empty?
      dash_matches = @query.scan(/\b(\d{3})-(\d{2})-(\d{2})\b/)
      tire_size_matches = dash_matches if dash_matches.any?
    end
    
    # Формат 5: 175/70 р13 (с пробелом перед R)
    if tire_size_matches.empty?
      space_r_matches = @query.scan(/\b(\d{3})\/(\d{2})\s+р?(\d{2})\b/i)
      tire_size_matches = space_r_matches if space_r_matches.any?
    end
    
    if tire_size_matches.any?
      width, height, diameter = tire_size_matches.last.map(&:to_i)
      if width >= 145 && width <= 335 && height >= 25 && height <= 85 && diameter >= 13 && diameter <= 24
        result[:tire_size] = {
          width: width,
          height: height,
          diameter: diameter,
          full_size: "#{width}/#{height}R#{diameter}"
        }
      end
    end

    # Поиск отдельного диаметра (например, "R18", "18", "диаметр 18")
    if result[:tire_size].blank?
      diameter_matches = @query.scan(/\b(?:r|диаметр\s*)?(\d{2})\b/i)
      if diameter_matches.any?
        diameter = diameter_matches.last.first.to_i
        if diameter >= 13 && diameter <= 24
          result[:diameter] = diameter
          Rails.logger.info "TireSearchService: Найден диаметр: R#{diameter}"
        end
      end
    end

    # Поиск бренда автомобиля (только целые слова)
    BRAND_ALIASES.each do |aliases, brand_name|
      if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
        result[:brand] = brand_name
        break
      end
    end

    # Если бренд не найден в алиасах - ищем динамически в БД
    if result[:brand].blank?
      dynamic_brand = find_brand_in_database(query_lower)
      result[:brand] = dynamic_brand if dynamic_brand.present?
    end

    # Поиск модели (если найден бренд)
    if result[:brand] && MODEL_ALIASES[result[:brand]]
      MODEL_ALIASES[result[:brand]].each do |aliases, model_name|
        if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
          result[:model] = model_name
          break
        end
      end
      
      # Если модель не найдена точно, попробуем найти с учетом расширений двигателей
      if result[:model].blank?
        result[:model] = find_model_with_engine_extensions(query_lower, result[:brand])
      end
    end

    # Поиск модели без бренда (для уникальных моделей)
    # ТОЛЬКО если бренд НЕ найден - иначе не перезаписываем уже найденный бренд
    if result[:model].blank? && result[:brand].blank?
      MODEL_ALIASES.each do |brand, models|
        models.each do |aliases, model_name|
          if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
            # Проверяем уникальность модели
            if is_unique_model?(model_name)
              result[:model] = model_name
              result[:brand] = brand
              break
            end
          end
        end
        break if result[:model].present?
      end
    end

    # Поиск года
    year_matches = @query.scan(/\b((19|20)\d{2})\b/)
    if year_matches.any?
      result[:year] = year_matches.last.first.to_i
    end

    # Поиск отдельных параметров размера (если не найден полный размер)
    unless result[:tire_size]
      # Найдем все числа в запросе и определим их типы
      tire_params = extract_tire_parameters(@query)
      
      if tire_params[:width] && tire_params[:height] && tire_params[:diameter]
        result[:tire_size] = {
          width: tire_params[:width],
          height: tire_params[:height],
          diameter: tire_params[:diameter],
          full_size: "#{tire_params[:width]}/#{tire_params[:height]}R#{tire_params[:diameter]}"
        }
      else
        # Сохраняем найденные отдельные параметры
        result[:width] = tire_params[:width] if tire_params[:width]
        result[:height] = tire_params[:height] if tire_params[:height]
        result[:diameter] = tire_params[:diameter] if tire_params[:diameter]
      end
    end

    # Поиск производителей шин (только целые слова)
    tire_brands = []
    TIRE_BRAND_ALIASES.each do |aliases, brand_name|
      if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
        tire_brands << brand_name
      end
    end
    result[:tire_brands] = tire_brands if tire_brands.any?

    # Поиск сезонности (только целые слова)
    SEASONALITY_ALIASES.each do |aliases, season|
      if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
        result[:seasonality] = season
        break
      end
    end

    result
  end

  def find_car_configurations
    scope = CarTireConfiguration.active.not_deprecated
    scope = scope.for_brand(@parsed_data[:brand]) if @parsed_data[:brand].present?
    scope = scope.for_model(@parsed_data[:model]) if @parsed_data[:model].present?
    scope = scope.for_year(@parsed_data[:year]) if @parsed_data[:year].present?
    scope.includes(:brand, :model)
  end

  def extract_tire_sizes_from_configurations(configurations)
    tire_sizes = []
    configurations.each do |config|
      config.tire_sizes.each do |size|
        # Фильтруем по диаметру если он указан в parsed_data
        if @parsed_data[:diameter].present?
          next unless size['diameter'] == @parsed_data[:diameter]
        end
        
        tire_sizes << {
          width: size['width'],
          height: size['height'],
          diameter: size['diameter'],
          type: size['type']
        }
      end
    end
    tire_sizes.uniq
  end

  def validate_tire_size_for_car(available_sizes)
    if @parsed_data[:tire_size].present?
      # Проверяем указанный полный размер
      requested_size = @parsed_data[:tire_size]
      matching_size = available_sizes.find do |size|
        size[:width] == requested_size[:width] &&
        size[:height] == requested_size[:height] &&
        size[:diameter] == requested_size[:diameter]
      end

      if matching_size
        {
          message: "Размер #{requested_size[:full_size]} подходит для данного автомобиля",
          tire_sizes: [requested_size]
        }
      else
        {
          message: "Размер #{requested_size[:full_size]} не найден для данного автомобиля, но возвращаем его по запросу",
          tire_sizes: [requested_size],
          warnings: ["Указанный размер может не подходить для данного автомобиля"]
        }
      end
    else
      # Возвращаем все доступные размеры
      {
        message: "Найдены размеры шин для #{@parsed_data[:brand]} #{@parsed_data[:model]}",
        tire_sizes: available_sizes
      }
    end
  end

  def extract_car_info
    info = {}
    info[:brand] = @parsed_data[:brand] if @parsed_data[:brand].present?
    info[:model] = @parsed_data[:model] if @parsed_data[:model].present?
    info[:year] = @parsed_data[:year] if @parsed_data[:year].present?
    info
  end

  def generate_car_suggestions
    # Предложения похожих автомобилей
    suggestions = []
    if @parsed_data[:brand].present?
      # Сначала пробуем статические алиасы (для быстрого доступа к ТОП-брендам)
      if MODEL_ALIASES[@parsed_data[:brand]]
        MODEL_ALIASES[@parsed_data[:brand]].each do |aliases, model_name|
          suggestions << "#{@parsed_data[:brand]} #{model_name}"
        end
      end
      
      # Если статических предложений мало - дополняем из БД
      if suggestions.length < 5
        dynamic_models = find_models_for_brand(@parsed_data[:brand])
        dynamic_models.each do |model_name|
          suggestion = "#{@parsed_data[:brand]} #{model_name}"
          suggestions << suggestion unless suggestions.include?(suggestion)
          break if suggestions.length >= 5
        end
      end
    end
    suggestions.take(5)
  end

  def generate_car_brand_suggestions
    # Предложения брендов автомобилей
    BRAND_ALIASES.values.sample(5)
  end

  def extract_tire_parameters(query)
    # Извлекаем все числа из запроса с контекстом
    params = { width: nil, height: nil, diameter: nil }
    
    # 1. Ищем диаметр (с контекстными подсказками и различными форматами)
    diameter_matches = query.scan(/(?:на\s+|r|\/|диаметр\s*)(\d{2})\b/i)
    if diameter_matches.any?
      diameter = diameter_matches.last.first.to_i
      params[:diameter] = diameter if diameter >= 13 && diameter <= 24
    end
    
    # 2. Ищем все двузначные и трехзначные числа
    all_numbers = query.scan(/\b(\d{2,3})\b/).flatten.map(&:to_i)
    
    # Исключаем уже найденный диаметр и года
    excluded_numbers = []
    excluded_numbers << params[:diameter] if params[:diameter]
    excluded_numbers += query.scan(/\b((19|20)\d{2})\b/).flatten.map(&:to_i)
    
    available_numbers = all_numbers - excluded_numbers
    
    # 3. Определяем ширину (трехзначное число 145-335)
    width_candidates = available_numbers.select { |n| n >= 145 && n <= 335 }
    if width_candidates.any?
      params[:width] = width_candidates.first
      available_numbers.delete(params[:width])
    end
    
    # 4. Определяем высоту (двузначное число 25-85)
    height_candidates = available_numbers.select { |n| n >= 25 && n <= 85 }
    if height_candidates.any?
      params[:height] = height_candidates.first
      available_numbers.delete(params[:height])
    end
    
    # 5. Если диаметр не найден по контексту, ищем среди оставшихся чисел
    if params[:diameter].nil?
      diameter_candidates = available_numbers.select { |n| n >= 13 && n <= 24 }
      if diameter_candidates.any?
        params[:diameter] = diameter_candidates.first
      end
    end
    
    params
  end

  def is_unique_model?(model_name)
    # Проверяем, встречается ли модель только у одного бренда
    brands_with_model = MODEL_ALIASES.count do |brand, models|
      models.any? { |aliases, name| name == model_name }
    end
    brands_with_model == 1
  end

  def needs_llm_parsing?
    # Используем LLM если простой парсинг НЕ нашел brand ИЛИ model
    # Но НЕ используем LLM если найден только диаметр без других слов - это нормальный случай
    if @parsed_data[:brand].blank? || @parsed_data[:model].blank?
      # Если найден только диаметр без других слов (например: "R16", "шины 18") - LLM не нужна
      # Но если есть другие слова кроме диаметра (например: "лада на 14") - нужен LLM
      diameter_only_query = @query.strip.match?(/^(шины\s+)?(r?\d{2,3}|на\s+\d{2,3})$/i)
      

      
      if @parsed_data[:diameter].present? && @parsed_data[:brand].blank? && @parsed_data[:model].blank? && diameter_only_query
        Rails.logger.info "LLM НЕ нужен: найден только диаметр R#{@parsed_data[:diameter]} без других слов"
        return false
      end
      
      # Если найдены частичные размеры шин - LLM не нужен
      partial_tire_size = (@parsed_data[:width].present? && @parsed_data[:height].present?) ||
                         (@parsed_data[:width].present? && @parsed_data[:diameter].present?) ||
                         (@parsed_data[:height].present? && @parsed_data[:diameter].present?)
      
      if partial_tire_size && @parsed_data[:brand].blank? && @parsed_data[:model].blank?
        Rails.logger.info "LLM НЕ нужен: найдены частичные размеры шин (width: #{@parsed_data[:width]}, height: #{@parsed_data[:height]}, diameter: #{@parsed_data[:diameter]})"
        return false
      end
      
      Rails.logger.info "LLM нужен: brand=#{@parsed_data[:brand].inspect}, model=#{@parsed_data[:model].inspect}, query='#{@query}'"
      return true
    end

    # Дополнительно используем LLM для сложных случаев даже если brand/model найдены
    complex_patterns = [
      @query.match?(/какие|посоветуйте|подойдет|нужны|помогите|скажите|подскажите/i), # Вопросительная форма
      @query.match?(/поменял|купил|заменил|установил|ищу|хочу/i), # Контекстные слова
      @query.split.length > 8,                     # Очень сложный запрос
      @query.match?(/не знаю|не уверен|не помню/i) # Неопределенность
    ]

    if complex_patterns.any?
      Rails.logger.info "LLM нужен: сложный запрос с паттернами"
      return true
    end

    # Если brand И model найдены и запрос простой - LLM не нужен
    Rails.logger.info "LLM НЕ нужен: простой запрос с найденными brand=#{@parsed_data[:brand]}, model=#{@parsed_data[:model]}"
    false
  end

  def parse_with_llm
    return {} unless OpenaiService.available?

    Rails.logger.info "🤖 Используем LLM для парсинга запроса: #{@query}"
    
    begin
      openai_service = OpenaiService.new
      result = openai_service.parse_tire_search_query(@query)
      
      if result.present?
        Rails.logger.info "✅ LLM успешно распарсил запрос: #{result.inspect}"
      else
        Rails.logger.warn "⚠️ LLM не смог распарсить запрос"
      end
      
      result
    rescue => e
      Rails.logger.error "❌ Ошибка LLM парсинга: #{e.message}"
      {}
    end
  end

  def search_configurations
    # Используем модель для поиска с приоритетом распознанных параметров
    search_params = @parsed_data.dup
    
    # Если не нашли конкретные параметры, используем общий поиск
    search_params[:query] = @query if search_params.empty? || search_params.values.compact.empty?
    
    Rails.logger.info "Search params: #{search_params.inspect}"
    
    CarTireConfiguration.search_with_filters(search_params)
                        .limit(@options[:limit] || 20)
                        .offset(@options[:offset] || 0)
  end

  def format_results(configurations)
    configurations.map do |config|
      {
        id: config.id,
        brand: config.brand.name,
        model: config.model.name,
        full_name: config.full_name,
        year_range: config.year_range,
        tire_sizes: config.formatted_tire_sizes,
        stock_sizes: config.stock_tire_sizes.map { |s| format_tire_size(s) },
        optional_sizes: config.optional_tire_sizes.map { |s| format_tire_size(s) },
        all_diameters: config.all_diameters,
        match_score: calculate_match_score(config),
        data_version: config.data_version
      }
    end
  end

  def format_tire_size(size)
    "#{size['width']}/#{size['height']}R#{size['diameter']}"
  end

  def calculate_match_score(config)
    score = 0
    query_lower = @query.downcase

    # Точное совпадение бренда
    score += 10 if query_lower.include?(config.brand.name.downcase)

    # Точное совпадение модели
    score += 8 if query_lower.include?(config.model.name.downcase)

    # Совпадение по поисковым токенам
    if config.search_tokens.present?
      score += 5 if config.search_tokens.downcase.include?(query_lower)
    end

    # Совпадение по году
    if @parsed_data[:year] && config.year_from <= @parsed_data[:year] && config.year_to >= @parsed_data[:year]
      score += 6
    end

    # Совпадение по диаметру
    if @parsed_data[:diameter] && config.all_diameters.include?(@parsed_data[:diameter])
      score += 4
    end

    score
  end

  def generate_suggestions
    suggestions = []

    # Если найден бренд, но нет модели - предлагаем модели этого бренда
    if @parsed_data[:brand].present? && @parsed_data[:model].blank?
      suggestions = generate_car_suggestions
      
      # Если для бренда нет моделей в алиасах - НЕ предлагаем фейковые модели
      # Вместо этого предлагаем альтернативные действия
      if suggestions.empty?
        suggestions = [
          "Введите размер шин (например: 205/55R16)",
          "Попробуйте другой автомобиль",
          "Выберите из популярных: BMW 3 Series, Toyota Camry, Volkswagen Golf"
        ]
      end
    end

    # Если нашли только модель без бренда
    if @parsed_data[:model].present? && @parsed_data[:brand].blank?
      BRAND_ALIASES.values.sample(3).each do |brand_name|
        suggestions << "#{brand_name} #{@parsed_data[:model]}"
      end
    end

    # Если вообще ничего не нашли
    if @parsed_data[:brand].blank? && @parsed_data[:model].blank?
      suggestions = [
        'BMW 3 Series',
        'Volkswagen Tiguan', 
        'Mercedes C-Class',
        'Toyota Camry',
        'Honda Civic'
      ]
    end

    suggestions.take(5)
  end

  def generate_follow_up_questions
    questions = []

    if @parsed_data[:brand].present? && @parsed_data[:model].blank?
      # Есть бренд, нужна модель
      questions << {
        type: "model_selection",
        question: "Какая модель #{@parsed_data[:brand]}?",
        field: "model",
        context: { brand: @parsed_data[:brand] }
      }
    end

    if @parsed_data[:brand].blank?
      # Нет бренда
      questions << {
        type: "brand_selection", 
        question: "Какая марка автомобиля?",
        field: "brand",
        context: {}
      }
    end

    if @parsed_data[:seasonality].blank?
      # Не указана сезонность
      questions << {
        type: "seasonality_selection",
        question: "Какие шины нужны?",
        field: "seasonality", 
        options: [
          { value: "winter", label: "Зимние" },
          { value: "summer", label: "Летние" },
          { value: "all_season", label: "Всесезонные" }
        ]
      }
    end

    questions.take(2) # Не более 2 вопросов за раз
  end

  def detect_unrecognized_input
    query_words = @query.downcase.split(/\s+/)
    
    # Проверяем, есть ли слова, которые выглядят как автомобильные термины, но не распознаны
    car_related_words = query_words.select do |word|
      # Слова длиннее 3 символов, не являющиеся числами или общими словами
      word.length > 3 && 
      !word.match?(/^\d+$/) && 
      !%w[шины авто автомобиль машина для на зимние летние всесезонные].include?(word)
    end
    
    # Если есть нераспознанные слова и ничего не найдено
    if car_related_words.any? && @parsed_data.values.compact.empty?
      car_related_words.first
    else
      nil
    end
  end

  def generate_alternative_suggestions
    [
      "BMW 3 Series",
      "Volkswagen Tiguan", 
      "Mercedes C-Class",
      "Toyota Camry",
      "Renault Logan",
      "Введите размер шин (например: 205/55R16)",
      "Попробуйте другой автомобиль"
    ]
  end

  def generate_alternative_questions
    [
      {
        type: "size_input",
        question: "Введите размер шин напрямую:",
        field: "tire_size",
        context: { example: "205/55R16" }
      },
      {
        type: "brand_selection",
        question: "Или выберите марку из популярных:",
        field: "brand",
        context: {}
      }
    ]
  end

  # Динамический поиск брендов в БД с транслитерацией
  def find_brand_in_database(query_lower)
    # Убираем стоп-слова и извлекаем потенциальные бренды
    words = extract_brand_words(query_lower)
    
    words.each do |word|
      # 1. Поиск с транслитерацией кириллицы
      transliterated_word = transliterate_to_latin(word)
      
      # 2. Поиск точного совпадения
      brand = find_exact_brand_match(transliterated_word)
      return brand.name if brand
      
      # 3. Поиск по началу названия
      brand = find_brand_by_prefix(transliterated_word)
      return brand.name if brand
      
      # 4. Поиск по содержанию (менее точный)
      brand = find_brand_by_partial_match(transliterated_word)
      return brand.name if brand
    end
    
    nil
  end

  # Извлечение слов-кандидатов на бренды
  def extract_brand_words(query_lower)
    words = query_lower.split(/[\s\+]+/)
    # Убираем стоп-слова
    stop_words = ['шины', 'на', 'для', 'под', 'авто', 'автомобиль', 'машину', 'тачку', 'тачка']
    words.reject { |w| stop_words.include?(w) || w.length < 2 }
  end

  # Транслитерация кириллицы в латиницу
  def transliterate_to_latin(cyrillic_word)
    transliteration_map = {
      'а' => 'a', 'б' => 'b', 'в' => 'v', 'г' => 'g', 'д' => 'd', 'е' => 'e', 'ё' => 'e',
      'ж' => 'zh', 'з' => 'z', 'и' => 'i', 'й' => 'y', 'к' => 'k', 'л' => 'l', 'м' => 'm',
      'н' => 'n', 'о' => 'o', 'п' => 'p', 'р' => 'r', 'с' => 's', 'т' => 't', 'у' => 'u',
      'ф' => 'f', 'х' => 'h', 'ц' => 'ts', 'ч' => 'ch', 'ш' => 'sh', 'щ' => 'sch',
      'ъ' => '', 'ы' => 'y', 'ь' => '', 'э' => 'e', 'ю' => 'yu', 'я' => 'ya'
    }
    
    # Специальные случаи для брендов
    brand_specific_map = {
      'теслу' => 'tesla', 'тесла' => 'tesla',
      'бмв' => 'bmw', 'бэмвэ' => 'bmw',
      'мерседес' => 'mercedes', 'мерс' => 'mercedes',
      'вольво' => 'volvo', 'волво' => 'volvo',
      'ауди' => 'audi',
      'тойота' => 'toyota', 'тойоту' => 'toyota',
      'хонда' => 'honda', 'хонду' => 'honda',
      'ниссан' => 'nissan', 'нисан' => 'nissan',
      'мазда' => 'mazda', 'мазду' => 'mazda',
      'хёндай' => 'hyundai', 'хундай' => 'hyundai',
      'киа' => 'kia', 'кию' => 'kia',
      'шкода' => 'skoda', 'шкоду' => 'skoda',
      'фольксваген' => 'volkswagen', 'фольцваген' => 'volkswagen'
    }
    
    # Сначала проверяем специальные случаи
    normalized_word = cyrillic_word.gsub(/[^\w]/, '').downcase
    return brand_specific_map[normalized_word] if brand_specific_map[normalized_word]
    
    # Общая транслитерация
    result = normalized_word
    transliteration_map.each { |cyrillic, latin| result = result.gsub(cyrillic, latin) }
    result
  end

  # Поиск точного совпадения бренда
  def find_exact_brand_match(word)
    return nil if word.blank? || word.length < 2
    
    CarBrand.where(is_active: true)
           .where('LOWER(name) = ?', word.downcase)
           .first
  end

  # Поиск по началу названия (более точный)
  def find_brand_by_prefix(word)
    return nil if word.blank? || word.length < 3
    
    CarBrand.where(is_active: true)
           .where('LOWER(name) LIKE ?', "#{word.downcase}%")
           .order(:name)
           .first
  end

  # Поиск по частичному совпадению (менее точный)
  def find_brand_by_partial_match(word)
    return nil if word.blank? || word.length < 3
    
    CarBrand.where(is_active: true)
           .where('LOWER(name) LIKE ?', "%#{word.downcase}%")
           .order(:name)
           .first
  end

  # Динамический поиск моделей для найденного бренда
  def find_models_for_brand(brand_name)
    brand = CarBrand.find_by(name: brand_name, is_active: true)
    return [] unless brand
    
    CarModel.where(brand_id: brand.id, is_active: true)
            .order(:name)
            .limit(10)
            .pluck(:name)
  end

  # Объединение текущих данных с контекстом из предыдущих шагов диалога
  def merge_with_context
    return if @context.blank?
    
    Rails.logger.info "TireSearchService: Merging context #{@context} with parsed data #{@parsed_data}"
    
    # Сохраняем контекст, если новые данные не перезаписывают его
    @context.each do |key, value|
      if value.present? && @parsed_data[key].blank?
        @parsed_data[key] = value
        Rails.logger.info "TireSearchService: Preserved from context: #{key} = #{value}"
      end
    end
    
    # Особая логика для tire_brands и seasonality - объединяем массивы
    if @context[:tire_brands].present?
      @parsed_data[:tire_brands] = (@parsed_data[:tire_brands] || []) | @context[:tire_brands]
    end
    
    # Если есть бренд из контекста и модель не найдена, попробуем найти модель в контексте бренда
    if @parsed_data[:brand].present? && @parsed_data[:model].blank?
      model = find_model_in_brand_context(@query.downcase, @parsed_data[:brand])
      if model.present?
        @parsed_data[:model] = model
        Rails.logger.info "TireSearchService: Found model in brand context: #{model}"
      end
    end
    
    # Логика для частичных размеров шин с учетом контекста
    if @context.present? && (@context[:width] || @context[:height] || @context[:diameter])
      # Если в контексте есть параметры размера, попробуем дополнить из текущего запроса
      partial_size = parse_partial_tire_size(@query, @context)
      if partial_size.present?
        @parsed_data.merge!(partial_size)
        Rails.logger.info "TireSearchService: Parsed partial tire size: #{partial_size}"
      end
    end
    
    Rails.logger.info "TireSearchService: Final merged data: #{@parsed_data}"
  end

  # Парсинг частичных размеров шин с учетом контекста
  def parse_partial_tire_size(query, context)
    # Извлекаем параметры из текущего запроса
    current_params = extract_tire_parameters(query)
    
    # Объединяем с контекстом, приоритет у текущего запроса
    merged_params = {}
    merged_params[:width] = current_params[:width] || context[:width]
    merged_params[:height] = current_params[:height] || context[:height] 
    merged_params[:diameter] = current_params[:diameter] || context[:diameter]
    
    # Проверяем, есть ли полный размер
    if merged_params[:width] && merged_params[:height] && merged_params[:diameter]
      if valid_tire_dimensions?(merged_params[:width], merged_params[:height], merged_params[:diameter])
        return {
          width: merged_params[:width],
          height: merged_params[:height],
          diameter: merged_params[:diameter],
          tire_size: {
            width: merged_params[:width],
            height: merged_params[:height],
            diameter: merged_params[:diameter],
            full_size: "#{merged_params[:width]}/#{merged_params[:height]}R#{merged_params[:diameter]}"
          }
        }
      end
    end
    
    # Возвращаем частичные параметры
    result = {}
    result[:width] = merged_params[:width] if merged_params[:width]
    result[:height] = merged_params[:height] if merged_params[:height]
    result[:diameter] = merged_params[:diameter] if merged_params[:diameter]
    
    result.any? ? result : nil
  end
  
  # Валидация размеров шин
  def valid_tire_dimensions?(width, height, diameter)
    # Проверяем разумные диапазоны для размеров шин
    width.between?(125, 355) &&    # Ширина от 125 до 355 мм
    height.between?(25, 85) &&     # Высота от 25% до 85%
    diameter.between?(12, 24)      # Диаметр от 12 до 24 дюймов
  end

  # Поиск модели в контексте определенного бренда
  def find_model_in_brand_context(query_lower, brand_name)
    return nil unless MODEL_ALIASES[brand_name]
    
    MODEL_ALIASES[brand_name].each do |aliases, model_name|
      if aliases.any? { |alias_name| query_lower.match?(/\b#{Regexp.escape(alias_name)}\b/) }
        return model_name
      end
    end
    
    # Поиск с учетом расширений двигателей
    find_model_with_engine_extensions(query_lower, brand_name)
  end

  # Поиск модели с учетом расширений двигателей (i, d, cdi, tdi и т.д.)
  def find_model_with_engine_extensions(query_lower, brand_name)
    return nil unless MODEL_ALIASES[brand_name]
    
    # Список распространенных расширений двигателей
    engine_extensions = %w[i d cdi tdi tfsi tsi dci hdi bluemotion xdrive quattro]
    
    MODEL_ALIASES[brand_name].each do |aliases, model_name|
      aliases.each do |alias_name|
        # Проверяем, есть ли в запросе базовая модель с расширением
        engine_extensions.each do |extension|
          # Паттерны для поиска: "320i", "320 i", "320-i"
          patterns = [
            "#{alias_name}#{extension}",           # 320i
            "#{alias_name} #{extension}",          # 320 i  
            "#{alias_name}-#{extension}",          # 320-i
            "#{alias_name}_#{extension}"           # 320_i
          ]
          
          if patterns.any? { |pattern| query_lower.match?(/\b#{Regexp.escape(pattern)}\b/) }
            Rails.logger.info "TireSearchService: Найдена модель с расширением: #{alias_name}#{extension} → #{model_name}"
            return model_name
          end
        end
      end
    end
    
    nil
  end

  # Проверка существования автомобиля в БД
  def car_exists_in_database?(brand_name, model_name)
    return false if brand_name.blank? || model_name.blank?
    
    brand = CarBrand.find_by(name: brand_name, is_active: true)
    return false unless brand
    
    CarModel.exists?(
      brand_id: brand.id, 
      name: model_name, 
      is_active: true
    )
  end

  # Умное объединение результатов простого парсинга и LLM
  def smart_merge_results(simple_data, llm_data)
    result = simple_data.dup

    # LLM может перезаписывать brand и model если:
    # 1. LLM нашел более полную информацию
    # 2. Комбинация LLM существует в БД, а простого парсинга - нет
    # 3. В запросе есть явное указание на бренд (пользователь хочет конкретный бренд)
    
    if llm_data[:brand].present? && llm_data[:model].present?
      # Проверяем какая комбинация лучше
      simple_car_exists = car_exists_in_database?(simple_data[:brand], simple_data[:model])
      llm_car_exists = car_exists_in_database?(llm_data[:brand], llm_data[:model])
      
      # Проверяем есть ли в запросе явное указание на бренд LLM
      query_lower = @query.downcase
      llm_brand_mentioned = query_lower.include?(llm_data[:brand].downcase) ||
                           brand_mentioned_in_query?(llm_data[:brand], query_lower)
      
      should_use_llm = false
      reason = ""
      
      if llm_car_exists && !simple_car_exists
        should_use_llm = true
        reason = "LLM найден в БД, простой парсинг - нет"
      elsif llm_car_exists && simple_car_exists && llm_brand_mentioned
        should_use_llm = true
        reason = "пользователь явно указал бренд #{llm_data[:brand]}"
      end
      
      if should_use_llm
        Rails.logger.info "LLM исправляет (#{reason}): #{simple_data[:brand]} #{simple_data[:model]} → #{llm_data[:brand]} #{llm_data[:model]}"
        result[:brand] = llm_data[:brand]
        result[:model] = llm_data[:model]
      end
    end

    # Для остальных полей - обычное слияние (LLM дополняет, не перезаписывает)
    llm_data.each do |key, value|
      next if [:brand, :model].include?(key) # brand и model обработаны выше
      result[key] = value if value.present? && result[key].blank?
    end

    result
  end

  # Проверяет упоминается ли бренд в запросе (включая алиасы)
  def brand_mentioned_in_query?(brand_name, query_lower)
    # Проверяем алиасы бренда
    BRAND_ALIASES.each do |aliases, alias_brand|
      if alias_brand == brand_name
        return aliases.any? { |alias_name| query_lower.include?(alias_name) }
      end
    end
    false
  end

  # Класс для статистики поиска
  class SearchStats
    def self.record_search(query, results_count, parsed_data = {})
      # Здесь можно записывать статистику поиска в Redis или БД
      Rails.logger.info "Search: '#{query}' -> #{results_count} results, parsed: #{parsed_data}"
    end

    def self.popular_queries(limit = 10)
      # Заглушка для популярных запросов
      [
        'BMW 3 Series',
        'Volkswagen Tiguan',
        'Mercedes C-Class',
        'Toyota Camry',
        'Honda Civic'
      ].take(limit)
    end
  end
end
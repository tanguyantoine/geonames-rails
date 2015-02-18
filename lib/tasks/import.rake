namespace :geonames do
  namespace :import do
    CACHE_DIR = Rails.root.join('db', 'geonames_cache')

    GEONAMES_FEATURES_COL_NAME = [
        :geonameid, :name, :asciiname, :alternatenames, :latitude, :longitude,
        :feature_class, :feature_code, :country_code, :cc2, :admin1_code,
        :admin2_code, :admin3_code, :admin4_code, :population, :elevation,
        :dem, :timezone, :modification
      ]
    GEONAMES_ALTERNATE_NAMES_COL_NAME = [
        :alternate_name_id, :geonameid, :isolanguage, :alternate_name,
        :is_preferred_name, :is_short_name, :is_colloquial, :is_historic
      ]
    GEONAMES_COUNTRIES_COL_NAME = [
        :iso, :iso3, :iso_numeric, :fips, :country, :capital, :area, :population, :continent,
        :tld, :currency_code, :currency_name, :phone, :postal_code_format, :postal_code_regex,
        :languages, :geonameid, :neighbours, :equivalent_fips_code
      ]
    GEONAMES_ADMINS_COL_NAME = [ :country_code, :admin1_code, :name, :asciiname, :geonameid ]
    GEONAMES_ADMINS2_COL_NAME = [ :country_code, :admin1_code, :admin2_code, :name, :asciiname, :geonameid ]

    desc 'Prepare everything to import data'
    
    task :prepare do
      require 'ruby-progressbar'
      require 'zip'
      Dir::mkdir(CACHE_DIR) rescue nil
      disable_logger
      disable_validations if ENV['SKIP_VALIDATION']
    end

    desc 'Import ALL geonames data.'
    task :all => [:many]

    desc 'Import most of geonames data. Recommended after a clean install.'
    task :many => [:prepare, :countries, :cities15000, :admin1, :admin2]

    desc 'Import all cities, regardless of population.'
    task :cities => [:prepare, :cities15000, :cities5000, :cities1000]

    class Array
      def rjust!(n, x); insert(0, *Array.new([0, n-length].max, x)) end
      def ljust!(n, x); fill(x, length...n) end
      def ljust(n, x); dup.fill(x, length...n) end
      def rjust(n, x); Array.new([0, n-length].max, x)+self end
    end

    desc 'Import feature data. Specify Country ISO code (example : COUNTRY=FR) for just a single country. NOTE: This task can take a long time!'
    task :features => [:prepare, :environment] do
      download_file = ENV['COUNTRY'].present? ? ENV['COUNTRY'].upcase : 'allCountries'
      txt_file = get_or_download("http://download.geonames.org/export/dump/#{download_file}.zip")
      # see http://www.geonames.org/export/codes.html
      ALLOWED_FEATURE_CLASS = Set.new(['A', 'P']).freeze
      FEATURE_CLASS_INDEX   =  6.freeze
      BUFFER                = 1000.freeze
      items = []
      filter_proc = ->(row){
        ALLOWED_FEATURE_CLASS.include?(row[FEATURE_CLASS_INDEX])
      }
      File.open(txt_file) do |f|
        insert_data(f, GEONAMES_FEATURES_COL_NAME, GeonamesCity, title: "Features", filter: filter_proc)
      end
    end


    # geonames:import:citiesNNN where NNN is population size.
    %w[15000 5000 1000].each do |population|
      desc "Import cities with population greater than #{population}"
      task "cities#{population}".to_sym => [:prepare, :environment] do

        txt_file = get_or_download("http://download.geonames.org/export/dump/cities#{population}.zip")

        File.open(txt_file) do |f|
          insert_data(f, GEONAMES_FEATURES_COL_NAME, GeonamesCity, title: "cities of #{population}")
        end
      end
    end

    desc 'Import countries informations'
    task :countries => [:prepare, :environment] do
      txt_file = get_or_download('http://download.geonames.org/export/dump/countryInfo.txt')

      File.open(txt_file) do |f|
        insert_data(f, GEONAMES_COUNTRIES_COL_NAME, GeonamesCountry, :title => "Countries")
      end
    end

    desc 'Import alternate names'
    task :alternate_names => [:prepare, :environment] do
      txt_file = get_or_download('http://download.geonames.org/export/dump/alternateNames.zip',
                                 txt_file: 'alternateNames.txt')
      LOCALES = Set.new(I18n.available_locales.map(&:to_s))
      LOCALE_INDEX  = GEONAMES_ALTERNATE_NAMES_COL_NAME.index(:isolanguage)
      filter = ->(row) { 
        !LOCALES.include?(row[LOCALE_INDEX])
      }
      File.open(txt_file) do |f|
        insert_data(f,
                    GEONAMES_ALTERNATE_NAMES_COL_NAME,
                    GeonamesAlternateName,
                    :title => "Alternate names",
                    :buffer => 10000,
                    :primary_key => [:alternate_name_id, :geonameid], filter: filter)
      end
    end

    desc 'Import iso language codes'
    task :language_codes => [:prepare, :environment] do
      txt_file = get_or_download('http://download.geonames.org/export/dump/alternateNames.zip',
                                 txt_file: 'iso-languagecodes.txt')

      File.open(txt_file) do |f|
        insert_data(f, GEONAMES_COUNTRIES_COL_NAME, GeonamesCountry, :title => "Countries")
      end
    end

    desc 'Import admin1 codes'
    task :admin1 => [:prepare, :environment] do
      txt_file = get_or_download('http://download.geonames.org/export/dump/admin1CodesASCII.txt')

      File.open(txt_file) do |f|
        prepare = ->(row) {
          row[0] = row[0].split('.').ljust(2, '')
          row.flatten
        }
        insert_data(f, GEONAMES_ADMINS_COL_NAME, GeonamesAdmin1, title: "Admin1 subdivisions", row_prepare: prepare)
      end
    end

    desc 'Import admin2 codes'
    task :admin2 => [:prepare, :environment] do
      txt_file = get_or_download('http://download.geonames.org/export/dump/admin2Codes.txt')

      File.open(txt_file) do |f|
        prepare = ->(row) {
          row[0] = row[0].split('.').ljust(2, '')
          row.flatten
        }
        insert_data(f, GEONAMES_ADMINS2_COL_NAME, GeonamesAdmin2, title: "Admin2 subdivisions", row_prepare: prepare)
      end
    end

    private
      ESCAPE_PROC = ->(val) {
        return val || 'NULL' unless val.is_a?(String)
        return 'NULL'  unless val.length > 0
        "'#{val.gsub("'", "''")}'"
      }

    def casters_for_klass(klass, cols)
      cols.inject([]) do |acc, col_name|
        begin
          acc << klass.columns.detect{|c| c.name == col_name.to_s }.cast_type
        rescue
          puts col_name.inspect
          raise 'error'
        end

        acc
      end
    end

    def insert_items(items, cols, klass, caster)
      query = "insert into #{klass.table_name} (#{cols.join(', ')}) values " 
      items.each do |row|
        query << '('
        row = caster.call(row) do |val|
          ESCAPE_PROC.call(val)
        end
        query << row.join(', ')
        query << '),'
      end
      query.slice!(-1) # remove last ','  
      ActiveRecord::Base.connection.execute query
    end

    def insert_data(file_fd, col_names, main_klass = GeonamesFeature, options = {}, &block)
      # Setup nice progress output.
      file_size = file_fd.stat.size
      title = options[:title] || 'Feature Import'
      buffer = options[:buffer] || 1000
      primary_key = options[:primary_key] || :geonameid
      progress_bar = ProgressBar.create(:title => title, :total => file_size, :format => '%a |%b>%i| %p%% %t')
      filter = options[:filter]

      polymorphic = !main_klass.columns.detect{|c| c.name == 'type' }.nil?
      col_names = col_names  + [ :type ]  if polymorphic
      # create block array
      # blocks = Geonames::Blocks.new
      loops = 0
      casters = casters_for_klass(main_klass, col_names)
      col_count = col_names.length
      items = []
      row_prepare = options[:row_prepare]
      cast_proc = -> (row, &block) { 
        row.each_with_index.map{ |el, i| 
          begin
            val = casters[i].type_cast_for_database(el) 
          rescue
            puts val
            raise "ok"
          end
          val = block.call(val) 
          val
        }
      }

      line_counter = 0
      file_fd.each_line do |line|
        # skip comments

        next if line.start_with?('#')
        row = line.strip.split("\t")
        row << main_klass.name if polymorphic
        row = row_prepare.call(row) if row_prepare
        row.ljust!(col_count, '')

        next if filter && filter.call(row)

        line_counter += 1
        items << row
        if line_counter % buffer == 0
          loops += 1
          puts "Insert items #{buffer * loops}."
          insert_items(items, col_names, main_klass, cast_proc )
          line_counter = 0
          items.clear
        end
        # move progress bar
        progress_bar.progress = file_fd.pos
      end
      insert_items(items, col_names, main_klass, cast_proc)
    end

    def disable_logger
      ActiveRecord::Base.logger = Logger.new('/dev/null')
    end

    def disable_validations
      ActiveRecord::Base.reset_callbacks(:validate)
    end


    def get_or_download(url, options = {})
      filename = File.basename(url)
      unzip = File.extname(filename) == '.zip'
      txt_filename = unzip ? "#{File.basename(filename, '.zip')}.txt" : filename
      txt_file_in_cache = File.join(CACHE_DIR, options[:txt_file] || txt_filename)
      zip_file_in_cache = File.join(CACHE_DIR, filename)

      unless File::exist?(txt_file_in_cache)
        puts 'file doesn\'t exists'
        if unzip
          download(url, zip_file_in_cache)
          unzip_file(zip_file_in_cache, CACHE_DIR)
        else
          download(url, txt_file_in_cache)
        end
      else
        puts "file already exists : #{txt_file_in_cache}"
      end

      ret = (File::exist?(txt_file_in_cache) ? txt_file_in_cache : nil)
    end

    def unzip_file(file, destination)
      puts "unzipping #{file}"
      Zip::File.open(file) do |zip_file|
        zip_file.each do |f|
          f_path = File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        end
      end
    end

    def download(url, output)
      File.open(output, "wb") do |file|
        body = fetch(url)
        puts "Writing #{url} to #{output}"
        file.write(body)
      end
    end

    def fetch(url)
      puts "Fetching #{url}"
      url = URI.parse(url)
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) {|http| http.request(req)}
      return res.body
    end



    # Return true when either:
    #  no filter keys apply.
    #  all applicable filter keys include the filter value.
    def filter?(attributes)
      return attributes.keys.all?{|key| filter_keyvalue?(key, attributes[key])}
    end

    def filter_keyvalue?(col, col_value)
      return true unless ENV[col.to_s]
      return ENV[col.to_s].split('|').include?(col_value.to_s)
    end

  end
end
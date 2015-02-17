namespace :geonames do
  namespace :db do
    namespace :truncate do
      desc 'Truncate all geonames data.'
      #task :all => [:countries, :cities, :admin1, :admin2]
      task :all => [:countries, :features]

      desc 'Truncate admin1 codes'
      task :admin1 => :environment do
        GeonamesAdmin1.delete_all #&& GeonamesAdmin1.reset_pk_sequence
      end

      desc 'Truncate admin2 codes'
      task :admin2 => :environment do
        GeonamesAdmin2.delete_all #&& GeonamesAdmin2.reset_pk_sequence
      end

      desc 'Truncate cities informations'
      task :cities => :environment do
        GeonamesCity.delete_all #&& GeonamesCity.reset_pk_sequence
      end

      def delete_reset_pk_sequence(klass)
        klass.send(:delete_all)
        ActiveRecord::Base.connection.reset_pk_sequence!(klass.table_name)
      end

      desc 'Truncate countries informations'
      task :countries => :environment do
        delete_reset_pk_sequence GeonamesCountry
      end

      desc 'Truncate features informations'
      task :features => :environment do
        delete_reset_pk_sequence GeonamesFeature
      end

      desc 'Truncate alternate names'
      task :alternate_names => :environment do
        delete_reset_pk_sequence GeonamesAlternateName
      end
    end
  end
end
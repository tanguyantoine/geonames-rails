namespace :geonames do
  desc "Download and insert geonames data"
  task :install => ['geonames:db:truncate:all', 'geonames:import:all'] do
    puts 'intalling'
  end
end
desc "Download and insert geonames data"
task :install => ['db:truncate', 'import:all']
end
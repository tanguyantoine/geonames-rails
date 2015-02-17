module Geonames
  class Engine < ::Rails::Engine
    rake_tasks do
      load "tasks/*.rake"
    end
  end
end

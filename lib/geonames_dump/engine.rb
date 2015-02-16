module GeonamesDump
  class Engine < ::Rails::Engine
    engine_name "geonames_dump"
    isolate_namespace GeonamesDump

    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
         app.config.paths["db/migrate"] += config.paths["db/migrate"].expanded
      end
    end
  end
end

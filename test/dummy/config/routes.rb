Rails.application.routes.draw do

  mount GeonamesDump::Engine => "/geonames_dump"
end

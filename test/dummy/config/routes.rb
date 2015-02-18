Rails.application.routes.draw do

  mount Geonames::Engine => "/geonames_dump"
end

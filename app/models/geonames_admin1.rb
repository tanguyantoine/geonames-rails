class GeonamesAdmin1 < GeonamesFeature
  def cities
    country.cities.where(admin1_code: admin1_code )
  end
end
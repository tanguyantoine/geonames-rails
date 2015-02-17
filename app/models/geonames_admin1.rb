class GeonamesAdmin1 < GeonamesFeature
  def admin2
    GeonamesAdmin2.where(country_code: country_code, admin1_code: admin1_code)
  end

  def cities
    country.cities.where(admin1_code: admin1_code )
  end
end
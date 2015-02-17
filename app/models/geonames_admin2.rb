class GeonamesAdmin2 < GeonamesFeature
  def cities
    country.cities.where( admin2_code: admin2_code, 
                          admin1_code: admin1_code
                        )
  end
end
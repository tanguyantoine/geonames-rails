class GeonamesCountry < ActiveRecord::Base
  validates_uniqueness_of :geonameid

  ##
  # search by iso first, then by name if not found
  #
  scope :search, lambda { |q|
    by_iso(q).count > 0 ? by_iso(q) : by_name(q)
  }

  ##
  # search by iso code
  #
  scope :by_iso, lambda { |q|
    where("iso = ? or iso3 = ?", q.upcase, q.upcase)
  }

  ##
  # search by name
  #
  scope :by_name, lambda { |q|
    where("country LIKE ?", "#{q}%")
  }

  has_many :cities, 
            primary_key: :iso, 
            foreign_key: :country_code,
            class_name: :GeonamesCity

  def admin1
    GeonamesAdmin1.where(country_code: iso)
  end

  def admin2
    GeonamesAdmin2.where(country_code: iso)
  end
end

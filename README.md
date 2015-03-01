# Geonames For Rails

## Installation

Quickly import countries, cities,  

based on : https://github.com/kmmndr/geonames_dump

Copy migrations
```ruby
rake geonames_engine:install:migrations 
```

Run migrations
```ruby
rake db:migrate 
```

Import data
```ruby
rake geonames:install 
```


## Use cases

### Create an autocomplete with Elastisearch

* Add name bahaviors to features

```ruby
GeonamesFeature.class_eval do
  default_scope { includes(:names) }

  def title
    localized = names.sort.first
    localized ? localized.alternate_name : name
  end
end

```

* Find best name for feature

```ruby
GeonamesAlternateName.class_eval do
  def <=>(other)
     other.score <=> score
  end

  def score
    @score = calculate_score
  end

  def calculate_score
    s = 0
    s += 1000 if I18n.locale == isolanguage.to_sym
    s += 100  if is_preferred_name
    s
  end
end
```


```ruby
GeonamesCity.class_eval do
  # ES mapping
  mapping do
    I18n.available_locales.each do |loc|
      indexes :country_code, index: :not_analyzed, type: :string
      indexes :population, index: :not_analyzed, type: :long
      indexes :geolocation, type: 'geo_point'
      indexes "name_#{loc}", type: :completion, 
                              payloads: true,
                              context: {
                                country: {
                                  type: :category,
                                  path: :country_code,
                                  default: ['*']
                                }
                              }
    end
  end
  
  def geolocation
    [latitude, longitude]
  end

  def reversed_geolocation
    geolocation.reverse
  end

  def as_indexed_json(opts = {})
    json = {
      country_code: [country_code, '*'],
      admin1_code: admin1_code,
      admin2_code: admin2_code,
      population: population,
      geolocation: reversed_geolocation # elasticsearch specificity
    }

    #custom method
    I18n.in_each_locale do |loc|
      t = self.title

      json["name_#{loc}"] = {
        input: [t, asciiname],
        output: [t, country_code].join(' - '),
        payload: { geonameid: geonameid, location: geolocation },
        weight: population
      }
    end
    json
  end

  # conutry permit to filter form iso code 
  def self.suggest(term, country = '*')
    res = __elasticsearch__.client.suggest \
      index: index_name,
      body: {
        name: {
          text: term,
          completion: {
            field: "name_#{I18n.locale}", 
            context: {
              country: country
            }
          }
        }
      }
    options = res['name']
    return [] unless options.present?
    options.first['options'].collect{|option|  option['payload'] }
  end
end

```

* In controller

```ruby
def cities
  render json: GeonamesCity.suggest(params[:term], params[:country_code])
end
```
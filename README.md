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


## Use



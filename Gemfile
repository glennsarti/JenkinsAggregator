source ENV['GEM_SOURCE'] || "https://rubygems.org"

gem 'rake', '~>10.1', :require => false
gem 'jenkins_api_client', '~> 1.0', :require => false

gem 'sinatra', :require => false
gem 'neo4j-core', :require => false

group :development do
#  gem 'rspec', '~>3.0',                     :require => false
end

# Evaluate Gemfile.local if it exists
if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# Evaluate ~/.gemfile if it exists
if File.exists?(File.join(Dir.home, '.gemfile'))
  eval(File.read(File.join(Dir.home, '.gemfile')), binding)
end

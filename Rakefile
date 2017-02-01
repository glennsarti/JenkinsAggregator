require 'rake'
require_relative 'lib/pipeline_aggregator'

desc 'Aggregates pipelines from Jenkins into singular jobs'
task :aggregate_jenkins do
  config_file = ENV['AGGREGATOR_CONFIG'] ? ENV['AGGREGATOR_CONFIG'] : File.expand_path("#{File.dirname(__FILE__)}/config.json")
  fail "Configuration file #{config_file} does not exist" unless File.exist?(config_file)
  config_data = File.read(config_file)

  agg = PipelineAggregator::Aggregator.new(config_data)

  agg.purge_job_cache
  agg.aggregate_from_jenkins
end

desc 'Generate static files for Jenkins API'
task :generate_api_server do
  config_file = ENV['AGGREGATOR_CONFIG'] ? ENV['AGGREGATOR_CONFIG'] : File.expand_path("#{File.dirname(__FILE__)}/config.json")
  fail "Configuration file #{config_file} does not exist" unless File.exist?(config_file)
  config_data = File.read(config_file)

  agg = PipelineAggregator::Aggregator.new(config_data)
  agg.build_jenkins_api
end


desc 'Executes a HTTP server simulating a Jenkins API'
task :jenkins_api_server do
  ruby File.expand_path("#{File.dirname(__FILE__)}/jenkins_api_server.rb")
end

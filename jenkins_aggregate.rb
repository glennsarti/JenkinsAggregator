require_relative 'lib/pipeline_aggregator'

config_filename = ENV['AGGREGATOR_CONFIG'] ? ENV['AGGREGATOR_CONFIG'] : File.expand_path("#{File.dirname(__FILE__)}/config.json")
config_data = File.read(config_filename)

agg = PipelineAggregator::Aggregator.new(config_data)

agg.aggregate_from_jenkins

agg.build_jenkins_api

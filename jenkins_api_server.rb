require 'sinatra'
require 'json'

require_relative 'lib/base'
require_relative 'lib/static_api_generator'

# TODO Don't hardcode this
set :port, 5001
set :bind, '0.0.0.0'

helpers do
  def jenkins_generator
    config_filename = ENV['AGGREGATOR_CONFIG'] ? ENV['AGGREGATOR_CONFIG'] : File.expand_path("#{File.dirname(__FILE__)}/config.json")
    config_data = JSON.parse(File.read(config_filename))
    return PipelineAggregator::APIGenerator::Neo4j.new(config_data)
  end
end

get '/' do
  'This is a fake Jenkins API HTTP server.  Try /api/json instead.'
end

get '/api/json' do
  result = jenkins_generator.jenkinsapi_get_root
  result == '' ? halt(404) : result
end

get '/view/:viewname/api/json' do
  viewname = params[:viewname]
  puts "Getting view #{viewname}"

  result = jenkins_generator.jenkinsapi_get_view(viewname)
  result == '' ? halt(404) : result
end

get '/job/:jobname/:buildnumber/api/json' do
  jobname = params[:jobname]
  buildnumber = params[:buildnumber]
  result = ''
  case buildnumber
  when 'lastBuild'
    puts "Getting latest build of job #{jobname}"
    result = jenkins_generator.jenkinsapi_get_last_build(jobname)
  else
    puts "Getting build #{buildnumber} of job #{jobname}"
    result = jenkins_generator.jenkinsapi_get_build(jobname,buildnumber)
  end
  result == '' ? halt(404) : result
end

get '/job/:jobname/api/json' do
  jobname = params[:jobname]
  puts "Getting job #{jobname}"

  result = jenkins_generator.jenkinsapi_get_job(jobname)
  result == '' ? halt(404) : result
end

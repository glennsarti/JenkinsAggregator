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

  def safe_get_file(filename)
    halt(500) unless File.exists?(filename)
    result = File.read(filename)
    result == '' ? halt(404) : result
  end
end

get '/' do
  'This is a fake Jenkins API HTTP server.  Try /api/json instead.'
end

get '/api/json' do
  generator = jenkins_generator
  safe_get_file(generator.get_root_json_filename)
end

get '/view/:viewname/api/json' do
  viewname = params[:viewname]
  puts "Getting view #{viewname}"

  generator = jenkins_generator
  safe_get_file(generator.get_view_filename(viewname))
end

get '/job/:jobname/:buildnumber/api/json' do
  jobname = params[:jobname]
  buildnumber = params[:buildnumber]
  generator = jenkins_generator
  filename = ''
  case buildnumber
  when 'lastBuild'
    puts "Getting latest build of job #{jobname}"
    filename = jenkins_generator.get_lastbuild_filename(jobname)
  else
    puts "Getting build #{buildnumber} of job #{jobname}"
    filename = jenkins_generator.get_build_filename(jobname,buildnumber)
  end
  safe_get_file(filename)
end

get '/job/:jobname/api/json' do
  jobname = params[:jobname]
  puts "Getting job #{jobname}"

  generator = jenkins_generator
  safe_get_file(generator.get_job_filename(jobname))
end

class PipelineAggregator::APIGenerator < PipelineAggregator::Base

  def initialize(config_data)
    @config_data = config_data

    # TODO Validate config file is correct

    #@jobs_dir = File.expand_path("#{api_directory}/jobs")
    #@builds_dir = File.expand_path("#{api_directory}/builds")
    #@working_dir  = File.expand_path("#{api_directory}/working")

    # Create data dirs if it doesn't exist
    #Dir.mkdir(api_directory) unless File.directory?(api_directory)
    #Dir.mkdir(@jobs_dir) unless File.directory?(@jobs_dir)
    #Dir.mkdir(@builds_dir) unless File.directory?(@builds_dir)
    #Dir.mkdir(@working_dir) unless File.directory?(@working_dir)
  end

  def get_buildfilename(project_unique_name,buildnumber)
    #File.expand_path("#{@builds_dir}/#{project_unique_name}_#{buildnumber}.json")
  end

  def generate
    fail "This should be overridden (generate)"
  end

  def jenkinsapi_get_job(jobname)
    fail "This should be overridden jenkinsapi_get_job(#{jobname})"
  end

  def jenkinsapi_get_build(jobname,buildnumber)
    fail "This should be overridden jenkinsapi_get_build(#{jobname},#{buildnumber})"
  end

  private
  def purge_working
    #log("Purging Working Directory")
    #Dir["#{@working_dir}/*.*"].map { |file| 
    #  File.delete(file)
    #}
  end

end

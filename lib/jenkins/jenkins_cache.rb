class PipelineAggregator::JenkinsCache < PipelineAggregator::Base

  def initialize(config_data)
    @config_data = config_data

    # TODO Validate config file is correct

    # Create data dirs if it doesn't exist
    Dir.mkdir(jobs_directory) unless File.directory?(jobs_directory)
    Dir.mkdir(builds_directory) unless File.directory?(builds_directory)
    Dir.mkdir(graphs_directory) unless File.directory?(graphs_directory)
  end

  def get_build_details_from_filename(filename)
    filename_split = filename.rpartition('_')
    build_number = filename_split.last
    filename_split = filename_split.first.partition('_')
    {
      'jenkins_master': filename_split.first,
      'jobname':         filename_split.last,
      'buildnumber':     build_number
    }
  end

  def get_job_details_from_filename(filename)
    filename_split = filename.partition('_')
    {
      'jenkins_master': filename_split.first,
      'jobname':         filename_split.last
    }
  end

  def purge_job_cache
    Dir["#{jobs_directory}/*.json"].map { |file| 
      File.delete(file)
    }
  end

  def cleanup_builds_cache
    # Only keep 100 builds for job
  end

  def get_all_jobs()
    Dir["#{jobs_directory}/*.json"].map { |file|
      filename = File.basename(file,'.json')
      yield get_job_details_from_filename(filename)
    }
  end

  def get_all_builds()
    Dir["#{builds_directory}/*.json"].map { |file| 
      filename = File.basename(file,'.json')
      yield get_build_details_from_filename(filename)
    }
  end

  def get_builds_without_graph()
    get_all_builds do |build_hash|
      yield build_hash unless File.exist?( buildgraphfilename(build_hash[:jenkins_master],build_hash[:jobname], build_hash[:buildnumber]) )
    end
  end 

  def get_build(jenkins_master,jobname,buildnumber)
    build_file = buildfilename(jenkins_master,jobname,buildnumber)

    if File.exist?(build_file)
      JSON.parse(File.read(build_file))
    else
      nil
    end
  end

  def get_builds_for_job(jenkins_master,jobname)
    get_all_builds do |build_hash|
      yield build_hash if build_hash[:jobname] == jobname
    end
  end

  def get_job(jenkins_master,jobname)
    job_file = jobfilename(jenkins_master,jobname)

    if File.exist?(job_file)
      JSON.parse(File.read(job_file))
    else
      nil
    end
  end

  def get_buildgraph(jenkins_master,jobname,buildnumber)
    filename = buildgraphfilename(jenkins_master,jobname,buildnumber)

    if File.exist?(filename)
      JSON.parse(File.read(filename))
    else
      nil
    end
  end

  # Set cache items
  def set_implicit_same_as_build(jenkins_master,jobname,buildnumber,causedby_jobname,causedby_buildnumber,sameas_buildnumber)
    value = {
      'implicit': {
        'jobname': causedby_jobname,
        'buildnumber': causedby_buildnumber,
        'same_as': {
          'jobname': jobname,
          'buildnumber': sameas_buildnumber
        }
      }
    }
    File.open(buildgraphfilename(jenkins_master,jobname,buildnumber), 'w') { |file| file.write( JSON.pretty_generate(value) ) }
  end
  def set_build_upstream_cause(jenkins_master,jobname,buildnumber,causedby_jobname,causedby_buildnumber)
    value = {
      'explicit': {
        'jobname': causedby_jobname,
        'buildnumber': causedby_buildnumber
      }
    }
    File.open(buildgraphfilename(jenkins_master,jobname,buildnumber), 'w') { |file| file.write( JSON.pretty_generate(value) ) }
  end
  def set_build_start_of_graph(jenkins_master,jobname,buildnumber)
    value = {
      'explicit': {
      }
    }
    File.open(buildgraphfilename(jenkins_master,jobname,buildnumber), 'w') { |file| file.write( JSON.pretty_generate(value) ) }
  end
  def set_build_attempts_expired(jenkins_master,jobname,buildnumber)
    value = {
      'attempts_expired': {
      }
    }
    File.open(buildgraphfilename(jenkins_master,jobname,buildnumber), 'w') { |file| file.write( JSON.pretty_generate(value) ) }
  end
  def set_job(jenkins_master,jobname,value)
    File.open(jobfilename(jenkins_master,jobname), 'w') { |file| file.write( JSON.pretty_generate(value) ) }
  end
  def set_build(jenkins_master,jobname,buildnumber,value)
    filename = buildfilename(jenkins_master,jobname,buildnumber)
    File.open(buildfilename(jenkins_master,jobname,buildnumber), 'w') { |file| file.write( JSON.pretty_generate(value) ) }
  end

  private
  def jobfilename(jenkins_master,jobname)
    File.expand_path("#{jobs_directory}/#{jenkins_master}_#{jobname}.json")
  end

  def buildfilename(jenkins_master,jobname,buildnumber)
    File.expand_path("#{builds_directory}/#{jenkins_master}_#{jobname}_#{buildnumber}.json")
  end

  def buildgraphfilename(jenkins_master,jobname,buildnumber)
    File.expand_path("#{graphs_directory}/#{jenkins_master}_#{jobname}_#{buildnumber}.json")
  end
end

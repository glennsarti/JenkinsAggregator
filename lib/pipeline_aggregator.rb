require 'jenkins_api_client'
require 'json'

require_relative 'base'
require_relative 'jenkins/jenkins_neo4j'
require_relative 'jenkins/jenkins'
require_relative 'static_api_generator'

class PipelineAggregator::Aggregator < PipelineAggregator::Base

  def initialize(config_json)
    @config_data = JSON.parse(config_json)

    # TODO Validate config file is correct

    # Create sub-objects
    @datastore = PipelineAggregator::JenkinsNeo4j.new(@config_data)
    @jenkins = PipelineAggregator::Jenkins.new(@config_data,@datastore)
  end

  public
  def purge_job_cache
    @datastore.purge_job_cache
  end

  def purge
    @datastore.purge
  end

  def build_jenkins_api
    generator = PipelineAggregator::APIGenerator::Neo4j.new(@config_data)
    generator.generate
  end

  def aggregate_from_jenkins
    log("Setting up the datastore...")
    @datastore.setup

    log("Starting to aggregate from jenkins")

    # Get all of the build jobs
    @config_data["projects"].each do |project|
      init_regex = project["init_job_regex"]

      branches = []
      @jenkins.get_jobnames(project["jenkins_master"],init_regex).each do |jobname|
        #match = /{init_regex}/.match(jobname)
        if jobname =~ /#{init_regex}/
          branches << $1
        end
      end
      branches.uniq!

      branches.each do |branch|
        get_job_pipeline(project,branch, false)
      end
    end

    log("Caching all builds for all jobs")
    # Cache all of the builds per job
    @datastore.get_all_jobs do |job|
      get_builds_for_job(job[:jenkins_master],job[:jobname])
    end

    log("Computing estimated duration")
    @datastore.compute_estimated_durations

    log("Generating build graph")
    @datastore.generate_buildgraph

    log("Cleaning up")
    @datastore.cleanup
  end

  private

  def get_builds_for_job(jenkins_master,jobname)
    log("Getting builds for job #{jobname}")
    job = @datastore.get_job(jenkins_master,jobname)

    job["builds"].each do |build|
      if !@datastore.get_build_exists?(jenkins_master,jobname,build["number"],true)
        build = @jenkins.get_build(jenkins_master,jobname,build["number"],false)
      end
    end
  end

  def get_job_pipeline(project,branch,use_cache = true)
    log("Parsing #{branch} branch of the #{project['name']} project")

    joblist = [{
      'jobname': project["init_job"].gsub(/##branch##/,branch),
      'depth': 1
    }]
    begin
      first_element = joblist.shift
      jobname = first_element[:jobname]
      jobdepth = first_element[:depth]
      log("Getting job #{jobname} (Depth #{jobdepth})")

      job = @jenkins.get_job(project["jenkins_master"],jobname,use_cache)

      if job['aggregator'].nil?
        job['aggregator'] = project
        job['aggregator']['order'] = jobdepth
        job['aggregator']['branch'] = branch

        @datastore.set_job(project["jenkins_master"],jobname,job)
      end

      # Add all of the downstream projects to the list
      job["downstreamProjects"].each do |downjob|
        joblist << {
          'jobname': downjob["name"],
          'depth': jobdepth + 1
        }
      end
    end until joblist.length == 0
  end

end

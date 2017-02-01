require 'neo4j-core'
require 'base64'

class PipelineAggregator::JenkinsNeo4j < PipelineAggregator::Base

  def initialize(config_data)
    @config_data = config_data

    # TODO Validate config file is correct

  end

  public
  def purge
    neo4j_session = get_session
    
    neo4j_session.query("MATCH ()-[r]-() DELETE r")
    neo4j_session.query("MATCH (n) DELETE n")
  end
  def purge_job_cache
    # Noop
  end

  def setup
    neo4j_session = get_session

    # Add jenkins masters
    # Use a standard sync-list pattern...
    cypher = "MATCH (j:jenkins) SET j.deleteme = 1;"
    ignore = neo4j_session.query(cypher)
    @config_data["jenkins_masters"].each do |master,data|
      cypher = "MERGE (j:jenkins {name:'#{master}', url: '#{data['server_url']}'})
                WITH j
                REMOVE j.deleteme"
      ignore = neo4j_session.query(cypher)
    end
    cypher = "MATCH (j:jenkins) WHERE EXISTS(j.deleteme)
              WITH j
              OPTIONAL MATCH (j)-[r]-() DELETE r
              WITH j
              DELETE j"
    ignore = neo4j_session.query(cypher)

    # Add projects
    cypher = "MATCH (proj:project) SET proj.deleteme = 1;"
    ignore = neo4j_session.query(cypher)
    @config_data["projects"].each do |project|
      cypher = "MERGE (proj:project {name: '#{ project['name'] }'})
                WITH proj
                REMOVE proj.deleteme"
      ignore = neo4j_session.query(cypher)
    end
    cypher = "MATCH (proj:project) WHERE EXISTS(proj.deleteme)
              WITH proj
              OPTIONAL MATCH (proj)-[r]-() DELETE r
              WITH proj
              DELETE proj"
    ignore = neo4j_session.query(cypher)

    # Cleanup orphaned jobs and builds
    cypher = "MATCH (b:build) WHERE (NOT (b)-[:JOB]->(:job))
              WITH b
              OPTIONAL MATCH (b)-[r]-() DELETE r
              WITH b
              DELETE b"
    ignore = neo4j_session.query(cypher)
  end

  def cleanup
    neo4j_session = get_session

    # Remove the file parameter as it takes up too much space and isn't required
    cypher = "MATCH (j:job) WHERE EXISTS(j.file) REMOVE j.file"
    ignore = neo4j_session.query(cypher)
    cypher = "MATCH (b:build) WHERE EXISTS(b.file) AND NOT EXISTS(b.generation_attempts) REMOVE b.file"
    ignore = neo4j_session.query(cypher)
  end

  # PROJECT
  def compute_estimated_durations
    neo4j_session = get_session

    cypher = "MATCH (j:job) RETURN ID(j) AS JobID"
    results = neo4j_session.query(cypher)
    results.each do |result|
      cypher = "MATCH (j)<-[:JOB]-(b:build)
                WHERE ID(j) = #{result.JobID} AND b.estimatedDuration <> -1
                WITH j,b
                ORDER BY b.timestamp DESC LIMIT 1
                SET j.estimatedDuration = b.estimatedDuration"
      ignore = neo4j_session.query(cypher)
    end
  end

  # JOB
  def get_job(jenkins_master,jobname)
    neo4j_session = get_session
    job_id = job_unique_name(jenkins_master,jobname)

    cypher = "MATCH (j:job {uid:'#{job_id}'}) RETURN j.file AS value"
    result = neo4j_session.query(cypher)

    result.count == 0 ? nil : JSON.parse(Base64.decode64(result.first.value))
  end

  def get_all_jobs
    neo4j_session = get_session

    results = neo4j_session.query("MATCH (j:job)-[:JENKINS]->(m:jenkins) RETURN j.name as JobName, m.name as JenkinsMaster")

    results.each do |result|
      value = {
        'jenkins_master': result.JenkinsMaster,
        'jobname': result.JobName
       }
      yield value
    end
  end

  def set_job(jenkins_master,jobname,value)
    neo4j_session = get_session
    job_id = job_unique_name(jenkins_master,jobname)

    valuetext = Base64.encode64(JSON.pretty_generate(value))

    result = neo4j_session.query("MERGE (j:job {uid:'#{job_id}'}) SET j.file = '#{valuetext}', j.name = '#{jobname}'")

    unless value['aggregator'].nil?
      order = value['aggregator']['order']

      implicit_params = value['aggregator']['implicit_build_graph_parameters'].join(';')
      versioning_params = value['aggregator']['versioning_build_parameters'].join(';')

      cypher = "MATCH (j:job {uid:'#{job_id}'})
                WITH j
                OPTIONAL MATCH (j)-[r:PROJECT]->(:project)
                DELETE r
                WITH j
                OPTIONAL MATCH (j)-[r:BRANCH]->(:branch)
                DELETE r
                WITH j
                OPTIONAL MATCH (j)-[r:JENKINS]->(:jenkins)
                DELETE r
                WITH j
                MERGE (branch:branch {name: '#{value['aggregator']['branch']}'})
                WITH j,branch
                MATCH (proj:project {name: '#{value['aggregator']['name']}'})
                MATCH (jenkins:jenkins {name: '#{value['aggregator']['jenkins_master']}'})
                CREATE (j)-[:PROJECT]->(proj)
                CREATE (j)-[:BRANCH]->(branch)
                CREATE (j)-[:JENKINS]->(jenkins)
                SET j.order = #{order}
                  ,j.implicit_params = '#{implicit_params}'
                  ,j.versioning_params = '#{versioning_params}'
                RETURN j.uid"
      result = neo4j_session.query(cypher)
    end
  end

  # BUILD
  def get_build_exists?(jenkins_master,jobname,buildnumber,ignore_jobs_that_are_building = false)
    neo4j_session = get_session
    build_id = build_unique_name(jenkins_master,jobname,buildnumber)

    cypher = "MATCH (b:build {uid:'#{build_id}'}) RETURN b.building AS building"
    result = neo4j_session.query(cypher)

    result.count == 0 ? false : !ignore_jobs_that_are_building || result.first.building != 'true'
  end
  def get_build(jenkins_master,jobname,buildnumber)
    neo4j_session = get_session
    build_id = build_unique_name(jenkins_master,jobname,buildnumber)

    cypher = "MATCH (b:build {uid:'#{build_id}'}) RETURN b.file AS value"
    result = neo4j_session.query(cypher)

    result.count == 0 ? nil : JSON.parse(Base64.decode64(result.first.value))
  end
  def set_build(jenkins_master,jobname,buildnumber,value)
    neo4j_session = get_session
    build_id = build_unique_name(jenkins_master,jobname,buildnumber)
    job_id = job_unique_name(jenkins_master,jobname)

    valuetext = Base64.encode64(JSON.pretty_generate(value))

    cypher = "MATCH (j:job {uid: '#{job_id}'})
              RETURN
                j.implicit_params AS implicit_params,
                j.versioning_params AS versioning_params"
    job_details = neo4j_session.query(cypher)

    # Extract the job properties we need
    paramlist = job_details.first.implicit_params.split(';') + job_details.first.versioning_params.split(';')
    paramlist.uniq!
    buildparams = get_build_parameters_from_build(value,paramlist).map do |name,param_value|
      ",b.#{name} = '#{param_value}'"
    end

    # Get an approximation of the version of this build
    buildversion = ''
    get_build_parameters_from_build(value,job_details.first.versioning_params.split(';')).each do |name,param_value|
      buildversion = param_value unless buildversion != ''
    end

    result = neo4j_session.query("MERGE (b:build {uid:'#{build_id}'})
                                  ON CREATE SET b.generation_attempts = 3
                                  WITH b
                                  SET b.file = '#{valuetext}'
                                    ,b.buildnumber = '#{buildnumber}'
                                    #{buildparams.join}
                                    ,b.timestamp = '#{value['timestamp']}'
                                    ,b.buildversion = '#{buildversion}'
                                    ,b.building = '#{value['building']}'
                                    ,b.duration = '#{value['duration']}'
                                    ,b.result = '#{value['result']}'
                                    ,b.url = '#{value['url']}'
                                    ,b.estimatedDuration = '#{value['estimatedDuration']}'
                                  WITH b
                                  MATCH (j:job {uid:'#{job_id}'})
                                  MERGE (b)-[:JOB]->(j)
                                  RETURN b.uid")
  end

  # Build Graph
  def generate_buildgraph
    neo4j_session = get_session

    # Pass 1
    # All init jobs (order == 1) don't have an upstream so don't care
    log("Generating build graph - Pass 1")
    cypher = 'MATCH (b:build)-[:JOB]->(j:job) WHERE j.order = 1 AND exists(b.generation_attempts) RETURN b.uid AS BuildUID'
    results = neo4j_session.query(cypher)
    results.each do |result|
      this_buildUID = result.BuildUID
      log("Found a graph start node for #{this_buildUID}")

      ignore = neo4j_session.query("MATCH (b:build {uid:'#{this_buildUID}'}) REMOVE b.generation_attempts")
    end

    # Pass 2
    # Builds may have an `actions/cause/upStreamCause` parameter, which happens when builds are triggered from other jobs (Explicit)
    log("Generating build graph - Pass 2")
    cypher = "MATCH (build:build)-[:JOB]->(job:job)-[:JENKINS]->(jenkins:jenkins) WHERE exists(build.generation_attempts)
                   RETURN build,job.uid AS JobUID,jenkins.name AS JenkinsName ORDER BY build.timestamp ASC"
    results = neo4j_session.query(cypher)
    results.each do |result|
      this_buildUID = result.build['uid']
      this_build = JSON.parse(Base64.decode64(result.build['file']))

      upstreamJobname = nil
      upstreamBuildNumber = nil

      this_build['actions'].each do |action|

        unless action['causes'].nil?
          action['causes'].each do |cause|
            unless cause['upstreamProject'].nil?
              upstreamJobname = cause['upstreamProject']
              upstreamBuildNumber = cause['upstreamBuild']
            end
          end
        end
      end
      unless upstreamJobname.nil?
        upstreamBuildUID = build_unique_name(result.JenkinsName,upstreamJobname,upstreamBuildNumber)
        log("Found an upstream cause for build #{this_buildUID} of build #{upstreamBuildUID}")
        cypher = "MATCH (me:build {uid:'#{this_buildUID}'})
                  REMOVE me.generation_attempts
                  WITH me
                  MATCH (upstream:build {uid:'#{upstreamBuildUID}'})
                  CREATE (upstream)-[:STARTED_BUILD {type:'EXPLICIT'}]->(me)"
        ignore = neo4j_session.query(cypher)
      end
    end

    # Pass 3
    # Look for builds within the same Job that have the same `implicit_build_graph_parameters` *AND* has an explicit upstream cause (Implicit)
    log("Generating build graph - Pass 3")
    cypher = "MATCH (build:build)-[:JOB]->(job:job)-[:JENKINS]->(jenkins:jenkins) WHERE exists(build.generation_attempts)
                   RETURN build,job.uid AS JobUID,job.implicit_params AS ImplicitParams,jenkins.name AS JenkinsName ORDER BY build.timestamp ASC"
    results = neo4j_session.query(cypher)
    results.each do |result|
      this_buildID = result.build.neo_id
      this_buildUID = result.build['uid']

      params_to_check = []
      result.ImplicitParams.split(';').each do |paramname|
        params_to_check << "this.#{paramname} = same.#{paramname}"
      end

      cypher = "MATCH (this:build)-[:JOB]->(:job)<-[:JOB]-(same:build)<-[:STARTED_BUILD {type:'EXPLICIT'}]-(upstream:build)
                WHERE ID(this) = #{this_buildID} AND #{params_to_check.join(' AND ')}
                RETURN ID(upstream) AS UpstreamID, upstream.uid AS UpstreamUID ORDER BY same.timestamp DESC LIMIT 1"
      implicit = neo4j_session.query(cypher)
      if implicit.count == 1
        log("Found an implicit cause for build #{this_buildUID} of build #{implicit.first.UpstreamUID}")
        cypher = "MATCH (me) WHERE ID(me) = #{this_buildID}
                  MATCH (upstream) WHERE ID(upstream) = #{implicit.first.UpstreamID}
                  CREATE (upstream)-[:STARTED_BUILD {type:'IMPLICIT'}]->(me)
                  WITH me
                  REMOVE me.generation_attempts"
        ignore = neo4j_session.query(cypher)
      end
    end

    # Pass Final
    # Decrement generation_attempts.  Any attempts <= 0 are marked as un-resolvable
    log("Generating build graph - Pass Final")
    cypher = "MATCH (build:build) WHERE exists(build.generation_attempts) SET build.generation_attempts = build.generation_attempts - 1"
    ignore = neo4j_session.query(cypher)
    cypher = "MATCH (build:build) WHERE exists(build.generation_attempts) AND build.generation_attempts <= 0 REMOVE build.generation_attempts"
    ignore = neo4j_session.query(cypher)

    true
  end

  private
  def get_session
    if @this_session.nil?
      @this_session = Neo4j::Session.open(:server_db, @config_data['neo4j']['uri'],
        {
          basic_auth: {
            username: @config_data['neo4j']['username'],
            password: @config_data['neo4j']['password']
          }
      })
    end

    @this_session
  end

  # private
  def job_unique_name(jenkins_master,jobname)
    "#{jenkins_master}_#{jobname}"
  end

  def build_unique_name(jenkins_master,jobname,buildnumber)
    "#{jenkins_master}_#{jobname}_#{buildnumber}"
  end

  def get_build_parameters_from_build(build, filter = nil)
    buildparams = {}
    unless build['actions'].nil?
      build['actions'].each do |action|
        unless action['parameters'].nil?
          action['parameters'].each do |param|
            if filter.nil? || filter.include?(param['name'])
              buildparams[param['name']] = param['value']
            end
          end
        end
      end
    end
    buildparams
  end
end

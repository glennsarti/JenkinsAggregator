require 'neo4j-core'
require 'base64'
require 'uri'

class PipelineAggregator::APIGenerator::Neo4j < PipelineAggregator::APIGenerator

  def initialize(config_data)
    super(config_data)
  end

  def generate
    neo4j_session = get_session

    log("Generating Jenkins API static files")
    purge_working

    # Generate the builds
    @config_data["projects"].each do |project|
      projectname = project['name']
      get_branches_for_project(projectname).each do |branch|
        project_unique_name = project["unique_name"].gsub(/##branch##/,branch)

        get_initial_builds_for_project(projectname,branch).each do |init_build_uid|
          log("Generating aggregated build for #{init_build_uid}")

          chain = get_aggregated_build_chain(init_build_uid)
          aggregate = buildchain_to_build(projectname,branch,chain)

          # Extra params for job construction

          extraparams = ["agg.buildnumber = #{aggregate[:number]}"]
          extraparams << ["agg.buildversion = '#{aggregate[:buildVersion]}'"]
          extraparams << ["agg.result = '#{aggregate[:result]}'"]
          extraparams << ["agg.url = '#{aggregate[:url]}'"]

          cypher = "MATCH (b:build {uid: '#{init_build_uid}'})
                    MERGE (agg:aggregate {uid: '#{init_build_uid}'})
                    SET agg.file = '#{Base64.encode64(JSON.pretty_generate(aggregate))}',
                        agg.jobname = '#{project_unique_name}'
                    ,#{extraparams.join(',')}
                    MERGE (agg)<-[:AGGREGATE]-(b)"
          ignore = neo4j_session.query(cypher)
        end
      end
    end

    nil
  end

  def jenkinsapi_get_root
    neo4j_session = get_session

    root_json = {
      "assignedLabels": [{ }],
      "mode": "EXCLUSIVE",
      "nodeDescription": "the master Jenkins node",
      "nodeName": "FAKE",
      "numExecutors": 1,
      "description": "Aggregated Jenkins Builds as a Jenkins API",
      "primaryView": nil,
      "quietingDown": false,
      "slaveAgentPort": 0,
      "unlabeledLoad": { },
      "useCrumbs": false,
      "useSecurity": true,
    }

    # Views list
    views = [{
      "name": "All",
      "url": localurl_root,
    }]
    projects = neo4j_session.query("MATCH (proj:project) RETURN proj.name AS ProjectName, ID(proj) AS ProjectID")
    projects.each do |project|
      views << {
        "name": project.ProjectName,
        "url": localurl_view(project.ProjectName),
      }
    end
    root_json['views'] = views

    # Jobs list
    jobs = []
    results = neo4j_session.query("MATCH (:build)-[:AGGREGATE]->(agg:aggregate) RETURN DISTINCT agg.jobname AS JobName")
    results.each do |result|
      jobs << {
        "name": result.JobName,
        "url": localurl_job(result.JobName),
        "color": 'notbuilt',
      }
    end
    root_json['jobs'] = jobs

    return JSON.pretty_generate(root_json)
  end

  def jenkinsapi_get_view(viewname)
    # The view comes in as a project's display name

    @config_data["projects"].each do |project|
      projectname = project['name']
      if projectname == viewname
        neo4j_session = get_session

        view_json = {
          "name": viewname,
          "property": [ ],
          "url": localurl_view(viewname)
        }

        # Get the jobs for the project
        results = neo4j_session.query(
          "MATCH (:project {name:'#{projectname}'})<-[:PROJECT]-(:job)<-[:JOB]-
          (:build)-[:AGGREGATE]->(agg:aggregate) RETURN DISTINCT agg.jobname AS JobName")
        jobs = []
        results.each do |result|
          jobs << {
            "name": result.JobName,
            "url": localurl_job(result.JobName),
            "color": 'notbuilt',
          }
        end
        view_json['jobs'] = jobs

        return JSON.pretty_generate(view_json)
      end
    end

    nil
  end

  def jenkinsapi_get_job(jobname)
    # The jobname comes in as a project's unique name
    @config_data["projects"].each do |project|
      projectname = project['name']
      get_branches_for_project(projectname).each do |branch|
        project_unique_name = project["unique_name"].gsub(/##branch##/,branch)

        if (jobname == project_unique_name)
          neo4j_session = get_session

          cypher = "MATCH (:branch {name: '#{branch}'})<-[:BRANCH]-(j:job)-[:PROJECT]->(:project {name: '#{projectname}'})
                    WITH j
                    MATCH (j)<-[:JOB]-(:build)-[:AGGREGATE]->(agg:aggregate)
                    RETURN agg.result AS result, agg.buildnumber AS buildnumber,
                           agg.url AS url, agg.buildversion AS buildversion
                    ORDER BY agg.buildnumber DESC LIMIT 20"
          agg_builds = neo4j_session.query(cypher)

          displayname = project["displayname"].gsub(/##branch##/,branch)
          if agg_builds.count > 0 && !agg_builds.first.buildversion.nil?
            displayname = displayname + " (#{agg_builds.first.buildversion})"
          end

          job_json = {
            'actions': [],
            'description': "Aggregated Jenkins Pipeline #{project_unique_name}",
            'displayName': displayname,
            'displayNameOrNull': displayname,
            'name': project_unique_name,
            'buildable': true,
            "property": [],
            "queueItem": nil,
            "concurrentBuild": false,
            "downstreamProjects": [],
            "scm": {},
            "upstreamProjects": [],
            "activeConfigurations": [],
            "nextBuildNumber": agg_builds.count == 0 ? 1 : agg_builds.first.buildnumber + 1,
          }

          healthscore = nil

          if agg_builds.count > 0
            # https://github.com/jenkinsci/jenkins/blob/master/core/src/main/java/hudson/model/BallColor.java#L56-L72
            case agg_builds.first.result
            when 'SUCCESS'
              job_json['color'] = 'blue'
            when ''
              job_json['color'] = 'blue_anime'
            when 'BUILDING'
              job_json['color'] = 'blue_anime'
            when 'ABORTED'
              job_json['color'] = 'aborted'
            else
              job_json['color'] = 'red'
            end
            job_json['url'] = agg_builds.first.url

            firstbuild_number = nil
            build_list = []
            last_completed_build = nil
            last_failed_build = nil
            last_succesful_build = nil

            valid_jobs_scored = 0
            healthscore = 0
            agg_builds.each do |agg_build|
              firstbuild_number = agg_build.buildnumber

              if valid_jobs_scored < 5 && (agg_build.result == 'FAILURE' || agg_build.result == 'SUCCESS')
                healthscore = healthscore + 1 if agg_build.result == 'SUCCESS'
                valid_jobs_scored = valid_jobs_scored + 1
              end

              build_list << {
                'number': agg_build.buildnumber,
                'url': localurl_build(jobname,agg_build.buildnumber),
              }
              
              if last_completed_build.nil? && agg_build.result == 'FAILURE' || agg_build.result == 'SUCCESS'
                last_completed_build = {
                  'number': agg_build.buildnumber,
                  'url': localurl_build(jobname,agg_build.buildnumber),
                }
              end
              if last_failed_build.nil? && agg_build.result == 'FAILURE'
                last_failed_build = {
                  'number': agg_build.buildnumber,
                  'url': localurl_build(jobname,agg_build.buildnumber),
                }
              end
              if last_succesful_build.nil? && agg_build.result == 'SUCCESS'
                last_succesful_build = {
                  'number': agg_build.buildnumber,
                  'url': localurl_build(jobname,agg_build.buildnumber),
                }
              end
            end

            job_json['firstBuild'] = {
              'number': firstbuild_number,
              'url': localurl_build(jobname,firstbuild_number),
            }
            job_json['lastBuild'] = {
              'number': agg_builds.first.buildnumber,
              'url': localurl_build(jobname,agg_builds.first.buildnumber),
            }
            job_json['builds'] = build_list
            job_json['lastCompletedBuild'] = last_completed_build
            job_json['lastFailedBuild'] = last_failed_build
            job_json['lastUnsuccessfulBuild'] = last_failed_build
            job_json['lastSuccessfulBuild'] = last_succesful_build
          else
            job_json['firstBuild'] = nil
            job_json['builds'] = nil
            job_json['lastCompletedBuild'] = nil
            job_json['lastFailedBuild'] = nil
            job_json['lastUnsuccessfulBuild'] = nil
            job_json['lastSuccessfulBuild'] = nil
            job_json['color'] = 'nobuilt'
            job_json['url'] = nil
          end
          # TODO Do I care about these?
          job_json['lastStableBuild'] = nil
          job_json['lastUnstableBuild'] = nil

          unless healthscore.nil? || valid_jobs_scored == 0
            # https://github.com/jenkinsci/jenkins/blob/master/core/src/main/java/hudson/model/HealthReport.java#L52
            # private static final String HEALTH_OVER_80 = "icon-health-80plus";
            # private static final String HEALTH_61_TO_80 = "icon-health-60to79";
            # private static final String HEALTH_41_TO_60 = "icon-health-40to59";
            # private static final String HEALTH_21_TO_40 = "icon-health-20to39";
            # private static final String HEALTH_0_TO_20 = "icon-health-00to19";

            # private static final String HEALTH_OVER_80_IMG = "health-80plus.png";
            # private static final String HEALTH_61_TO_80_IMG = "health-60to79.png";
            # private static final String HEALTH_41_TO_60_IMG = "health-40to59.png";
            # private static final String HEALTH_21_TO_40_IMG = "health-20to39.png";
            # private static final String HEALTH_0_TO_20_IMG = "health-00to19.png";
            healthpercent = healthscore / valid_jobs_scored * 100
            iconClassName = 'icon-health-80plus'
            iconURL = 'health-80plus.png'
            case healthpercent
            when 0..20
              iconClassName = 'icon-health-00to19'
              iconURL = 'health-00to19.png'
            when 21..40
              iconClassName = 'icon-health-20to39'
              iconURL = 'health-20to39.png'
            when 41..60
              iconClassName = 'icon-health-40to59'
              iconURL = 'health-40to59.png'
            when 61..80
              iconClassName = 'icon-health-60to79'
              iconURL = 'health-60to79.png'
            end

            job_json
            job_json['healthReport'] = [{
              'description': "Build stability: #{valid_jobs_scored - healthscore} out of the last #{valid_jobs_scored} builds failed",
              'iconClassName': iconClassName,
              'iconURL': iconURL,
              'score': healthpercent,
            }]
          end

          return JSON.pretty_generate(job_json)
        end
      end
    end
    
    nil
  end

  def jenkinsapi_get_last_build(jobname)
    @config_data["projects"].each do |project|
      projectname = project['name']
      get_branches_for_project(projectname).each do |branch|
        project_unique_name = project["unique_name"].gsub(/##branch##/,branch)
        if (jobname == project_unique_name)
          neo4j_session = get_session

          cypher = "MATCH (:branch {name: '#{branch}'})<-[:BRANCH]-(j:job)-[:PROJECT]->(:project {name: '#{projectname}'})
                    WITH j
                    MATCH (j)<-[:JOB]-(:build)-[:AGGREGATE]->(agg:aggregate)
                    RETURN agg.file AS response
                    ORDER BY agg.buildnumber DESC
                    LIMIT 1"
          agg_build = neo4j_session.query(cypher)
          return (agg_build.count == 0 ? nil : Base64.decode64( agg_build.first.response) )
        end
      end
    end
  end

  def jenkinsapi_get_build(jobname,buildnumber)
    @config_data["projects"].each do |project|
      projectname = project['name']
      get_branches_for_project(projectname).each do |branch|
        project_unique_name = project["unique_name"].gsub(/##branch##/,branch)
        if (jobname == project_unique_name)
          neo4j_session = get_session

          cypher = "MATCH (:branch {name: '#{branch}'})<-[:BRANCH]-(j:job)-[:PROJECT]->(:project {name: '#{projectname}'})
                    WITH j
                    MATCH (j)<-[:JOB]-(:build)-[:AGGREGATE]->(agg:aggregate {buildnumber: #{buildnumber}})
                    RETURN agg.file AS response"
          agg_build = neo4j_session.query(cypher)
          return (agg_build.count == 0 ? nil : Base64.decode64( agg_build.first.response) )
        end
      end
    end

    nil
  end

  private
  def localurl_root
    "http://localhost:5001"
  end
  def localurl_view(viewname)
    URI.escape("#{localurl_root}/view/#{viewname}/")
  end
  def localurl_build(jobname,buildnumber)
    URI.escape("#{localurl_root}/job/#{jobname}/#{buildnumber}/")
  end
  def localurl_job(jobname)
    URI.escape("#{localurl_root}/job/#{jobname}/")
  end

  def get_session
    if @this_session.nil?
      @this_session = ::Neo4j::Session.open(:server_db, @config_data['neo4j']['uri'],
        {
          basic_auth: {
            username: @config_data['neo4j']['username'],
            password: @config_data['neo4j']['password']
          }
      })
    end

    return @this_session
  end

  def get_branches_for_project(projectname)
    neo4j_session = get_session

    cypher = "MATCH (p:project {name:'#{projectname}'})<-[:PROJECT]-(:job)-[:BRANCH]->(b:branch) RETURN DISTINCT b.name AS BranchName"
    results = neo4j_session.query(cypher)
    branches = []
    results.each do |result|
      branches << result.BranchName
    end

    branches
  end

  def get_initial_builds_for_project(projectname,branch)
    neo4j_session = get_session

    cypher = "MATCH (:project {name:'#{projectname}'})<-[:PROJECT]-(j:job {order:1})-[:BRANCH]->(:branch {name:'#{branch}'})
              WITH j
              MATCH (j)<-[:JOB]-(b:build)
              RETURN b.uid AS BuildUID, b.buildnumber AS BuildNumber ORDER BY b.timestamp DESC"
    results = neo4j_session.query(cypher)
    builds = []
    results.each do |result|
      builds << result.BuildUID
    end

    builds
  end

  def get_aggregated_build_chain(init_build_uid)
    neo4j_session = get_session
    cypher = "MATCH (start:build {uid:'#{init_build_uid}'})-[:STARTED_BUILD*0..10]->(end:build)
              WITH start,end
              ORDER BY end.timestamp DESC LIMIT 1
              WITH start,end
              MATCH p=(start)-[:STARTED_BUILD*0..10]->(end)
              RETURN NODES(p) AS BuildChain"
    results = neo4j_session.query(cypher)
    chain = []
    results.first.BuildChain.each do |result|
      chain << {
        'uid':          result['uid'],
        'buildnumber':  result['buildnumber'],
        'buildversion': result['buildversion'],
        'duration':     result['duration'],
        'estimatedduration':     result['estimatedDuration'],
        'building':     result['building'],
        'timestamp':    result['timestamp'],
        'result':       result['result'],
        'url':          result['url'],
      }
    end

    chain
  end

  def buildchain_to_build(projectname,branch,chain)
    last_build = chain.last
    first_build = chain.first

    buildversion = ''
    totalduration = 0
    total_estimated_duration = 0
    chain.each do |node|
      totalduration = totalduration + node[:duration].to_i
      if node[:estimatedduration].to_i > 0
        total_estimated_duration = total_estimated_duration + node[:estimatedduration].to_i
      end
      buildversion = "#{node[:buildversion]}" unless buildversion != ''
    end

    build = {
      "actions": [
        {
          "parameters": []
        },
      ],
      "artifacts": [],
      "building": !!last_build[:building],
      "buildVersion": buildversion,
      "description": nil,
      "displayName": "##{first_build[:buildnumber]}",
      "duration": !!last_build[:building] ? 0 : totalduration,
      "estimatedDuration": total_estimated_duration,
      "executor": nil,
      "fullDisplayName": "#{projectname} (#{branch}) #{buildversion} -- ##{first_build[:buildnumber]}",
      "id": "#{first_build[:buildnumber]}",
      "keepLog": false,
      "number": first_build[:buildnumber].to_i,
      "result": last_build[:result],
      "timestamp": first_build[:timestamp].to_i,
      "url": last_build[:url],
      "builtOn": "fakebuilder",
      "changeSet": { },
    }

    build
  end
end

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
config_dir = File.expand_path("../../config", __FILE__)

#require 'pry'
require 'byebug'
require 'base64'
require 'faraday'
require 'logger'
require 'gitlab/gitlab_proxy'
require_relative "#{config_dir}/environment"

module CrossCloudCI
  module CiService
    #def self.client(options = {})
    def self.client(config)
      CrossCloudCI::CiService::Client.new(config)
    end
  end
end

# module CrossCloudCI
#   module CiService
#     class Build
#       attr_accessor :build_id, :project_name, :project_id, :project_ref
#
#       def initialize(project_id, build_id, project_name, project_ref)
#         @project_id, @build_id, @project_name, @project_ref = project_id, build_id, project_name, project_ref
#       end
#
#       def status
#         build_status(@project_id, @build_id)
#       end
#
#       private
#
#       # def build_status
#       # end
#     end
#   end
# end
 

module CrossCloudCI
  module CiService
    class Client
      attr_accessor :logger
      attr_accessor :config
      attr_accessor :gitlab_proxy
      attr_accessor :projects, :active_projects,  :all_gitlab_projects, :active_gitlab_projects, :active_clouds
      attr_accessor :builds, :builds2, :app_deploys, :provisionings

      #def initialize(options = {})
      def initialize(config)
        @config = config
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::DEBUG

        @project_name_id_mapping = {}
        @builds = { :provision_layer => [], :app_layer => [] }
        @builds2 = []
        @provisionings = []
        @app_deploys = []

        @gitlab_proxy = CrossCloudCI::GitLabProxy.proxy(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
        #@gitlab_proxy = CrossCloudCI::GitLabProxy.proxy(:endpoint => options[:endpoint], :api_token => options[:api_token])
      end

      def build_project(project_id, ref, options = {})
        project_name = project_name_by_id(project_id)

        @logger.debug "setting api token for #{project_name}"
        if options[:api_token]
          api_token = options[:api_token]
        else
          api_token = @config[:gitlab][:pipeline][project_name][:api_token]
        end

        trigger_variables = {}

        @logger.debug "#{project_name} project id: #{project_id}, api token: #{api_token}, ref:#{ref}"
        @logger.debug "options var: #{options.inspect}"

        trigger_variables[:DASHBOARD_API_HOST_PORT] = options[:dashboard_api_host_port] unless options[:dashboard_api_host_port].nil?
        trigger_variables[:CROSS_CLOUD_YML] = @config[:cross_cloud_yml]

        gitlab_result = nil
        tries=3
        begin
          @logger.debug "Calling Gitlab API for #{project_name} trigger_pipeline(#{project_id}, #{api_token}, #{ref}, #{trigger_variables})"
          gitlab_result = @gitlab_proxy.trigger_pipeline(project_id, api_token, ref, trigger_variables)
          @logger.debug "gitlab proxy result: #{gitlab_result.inspect}"
        rescue Gitlab::Error::InternalServerError => e
          @logger.error "Gitlab Proxy error: #{e}"

          tries -= 1
          if tries > 0
            @logger.info "Trying to trigger pipeline for project #{project_name} again: #{project_id}, ref #{ref}"
            retry
          else
            @logger.error "Failed to trigger pipeline for project #{project_name}: #{project_id}, ref #{ref}"
            return
          end
        end

        gitlab_pipeline_id = gitlab_result.id
        data = {  project_name: project_name, ref: ref, project_id: project_id, pipeline_id: gitlab_pipeline_id }
        if @config[:projects][project_name]["app_layer"]
          @builds[:app_layer] << data
        else
          @builds[:provision_layer] << data
        end
        #@builds2 << CrossCloudCI::CiService::Build.new(project_id, build_id, project_name, ref)
        data
      end

      #def build_status(project_name, build_id)
      def build_status(project_id, build_id)
        #project_id = project_id_by_name(project_name) unless project_name.nil?
        jobs = @gitlab_proxy.get_pipeline_jobs(project_id, build_id)
        status = jobs.select {|j| j["name"] == "container"}.first["status"]
        if status == "created"
          status = jobs.select {|j| j["name"] == "compile"}.first["status"]
        end
        status
      end

      # TODO: #5) implement provision function
      #  - use build artifacts / pipeline id
      def provision_cloud(cloud, options = {})
        trigger_variables = {}

        # GitLab pipeline to trigger
        project_name = "cross-cloud"
        project_id = project_id_by_name("cross-cloud")
        # related to environment, eg. cidev, master, staging, production
        #
        # TODO: use ref from yaml
        trigger_ref = options[:provision_ref]

        @logger.debug "setting api token for #{project_name}"
        if options[:api_token]
          api_token = options[:api_token]
        else
          api_token = @config[:gitlab][:pipeline][project_name][:api_token]
        end

        #@logger.debug "#{project_name} project id: #{project_id}, api token: #{api_token}, ref:#{ref}"
        @logger.debug "options var: #{options.inspect}"

        trigger_variables[:CLOUD] = cloud

        target_project_name = "kubernetes"
        target_project_id = project_id_by_name(target_project_name)
        kubernetes_project_id = target_project_id
        target_project_ref = options[:kubernetes_ref] unless options[:kubernetes_ref].nil?

        trigger_variables[:SOURCE] = options[:kubernetes_build_id] unless options[:kubernetes_build_id].nil?
        trigger_variables[:PROJECT_ID] = kubernetes_project_id
        trigger_variables[:PROJECT_BUILD_PIPELINE_ID] = options[:kubernetes_build_id] unless options[:kubernetes_build_id].nil?

        trigger_variables[:TARGET_PROJECT_ID] = target_project_id
        trigger_variables[:TARGET_PROJECT_NAME] = target_project_name
        trigger_variables[:TARGET_PROJECT_COMMIT_REF_NAME] = target_project_ref

        trigger_variables[:DASHBOARD_API_HOST_PORT] = options[:dashboard_api_host_port] unless options[:dashboard_api_host_port].nil?
        #trigger_variables[:CROSS_CLOUD_YML] = options[:cross_cloud_yml] unless options[:cross_cloud_yml].nil?
        trigger_variables[:CROSS_CLOUD_YML] = @config[:cross_cloud_yml]

        gitlab_result = nil
        tries=3
        begin
          @logger.debug "Calling Gitlab API for #{project_name} trigger_pipeline(#{project_id}, #{api_token}, #{trigger_ref}, #{trigger_variables})"
          gitlab_result = @gitlab_proxy.trigger_pipeline(project_id, api_token, trigger_ref, trigger_variables)
          @logger.debug "gitlab proxy result: #{gitlab_result.inspect}"
        rescue Gitlab::Error::InternalServerError => e
          @logger.error "Gitlab Proxy error: #{e}"

          tries -= 1
          if tries > 0
            @logger.info "Trying to trigger pipeline for project #{project_name} again: #{project_id}, ref #{trigger_ref}"
            retry
          else
            @logger.error "Failed to trigger pipeline for project #{project_name}: #{project_id}, ref #{trigger_ref}"
            return
          end
        end

        gitlab_pipeline_id = gitlab_result.id
        data = { project_name: target_project_name, target_project_ref: target_project_ref, trigger_ref: trigger_ref, target_project_id: target_project_id, project_id: project_id, pipeline_id: gitlab_pipeline_id, cloud: cloud }
        @provisionings << data
        data
      end

      def retrieve_kubeconfig(project_id, pipeline_id, api_token, cloud)
        # TODO: pull job name from cross cloud yaml
        job_id = pipeline_job_by_name(project_id, pipeline_id, "Provisioning")["id"]


        # TODO: move retrive into gitlab_proxy for single artifact download
        #
        # GET /projects/:id/jobs/:job_id/artifacts/*artifact_path
        #
        url = "#{@config[:gitlab][:base_url]}/cncf/cross-cloud/-/jobs/#{job_id}/artifacts/raw/data/#{cloud}/kubeconfig"
        #url = "#{@config[:gitlab][:base_url]}/projects/#{project_id}/-/jobs/#{job_id}/artifacts/data/#{cloud}/kubeconfig"

        @logger.debug url

        response = Faraday.get url
        if response.body.nil?
          @logger.error "Failed to download kubeconfig for cloud #{cloud}"
          return
        end

        response.body
      end

      def pipeline_job_by_name(project_id, pipeline_id, job_name)
        jobs = []
        tries=3
        begin
          jobs = @gitlab_proxy.get_pipeline_jobs(project_id, pipeline_id)

        rescue Gitlab::Error::InternalServerError => e
          @logger.error "Gitlab Proxy error: #{e}"

          tries -= 1
          if tries > 0
            @logger.info "Trying get_pipeline_jobs again"
            retry
          else
            @logger.error "Failed get_pipeline_jobs"
            return
          end
        end

        jobs.select {|j| j["name"] == job_name}.first
      end

      def provision_status(provision_id)
        project_id = project_id_by_name["cross-cloud"]
        tries=3
        begin
          jobs = @gitlab_proxy.get_pipeline_jobs(project_id, provision_id)

        rescue Gitlab::Error::InternalServerError => e
          @logger.error "Gitlab Proxy error: #{e}"

          tries -= 1
          if tries > 0
            @logger.info "Trying get_pipeline_jobs again"
            retry
          else
            @logger.error "Failed get_pipeline_jobs"
            return
          end
        end
        status = jobs.select {|j| j["name"] == "Provisioning"}.first["status"]
        status
      end

      # TODO: #6) implement cloud provision loop for all active clouds
      #  - Required: config including cross-cloud config
      def provision_active_clouds
        # TODO:
        # - get active clouds
        #  - pull kubernetes kubeconfig
        # - pull kubernetes build id for stable and head/master from build stage
        # - loop for active couds
        # - loop for stable and head/master on each cloud
        # - use kubernetes build id for stable and head/master based on previous build stage
        # - use kubernetes ref for stable and head/master based on config

        load_project_data
        load_cloud_data

        # TODO: Support loading builds from GitLab
        if @builds.nil? or @builds.empty?
          @logger.error "Builds needed before provisioning"
          return
        end

        latest_k8s_builds = @builds[:provision_layer].sort! {|x,y| x[:pipeline_id] <=> y[:pipeline_id]}.slice(-2,2)

        kubernetes_head = latest_k8s_builds.select {|b| b[:ref] == "master" }.first
        kubernetes_stable = latest_k8s_builds.select {|b| b[:ref] != "master" }.first

        @active_clouds.each do |cloud|
          cloud_name = cloud[0]
          #next unless cloud_name == "gce"
          @logger.info "Active cloud: #{cloud_name}"

          [:stable, :head].each do |release|
            case release
            when :stable
              kubernetes_build = kubernetes_stable
            else
              kubernetes_build = kubernetes_head
            end

            build_id = kubernetes_build[:pipline_id]
            ref = kubernetes_build[:kubernetes_ref]

            options = {}
            options = {
              dashboard_api_host_port: @config[:dashboard][:dashboard_api_host_port],
              cross_cloud_yml: @config[:cross_cloud_yml], 
              kubernetes_build_id: build_id,
              kubernetes_ref: ref,
              api_token: @config[:gitlab][:pipeline]["cross-cloud"][:api_token],
              provision_ref: @config[:gitlab][:pipeline]["cross-cloud"][:cross_cloud_ref]
            }

            self.provision_cloud(cloud_name, options)
            #self.provision_cloud(cloud_name, {:kubernetes_build_id => 5413, :kubernetes_ref => "v1.8.1", :dashboard_api_host_port => "devapi.cncf.ci", :cross_cloud_yml => @config[:cross_cloud_yml], :api_token => @config[:gitlab][:pipeline]["cross-cloud"][:api_token], :provision_ref => @config[:gitlab][:pipeline]["cross-cloud"][:cross_cloud_ref]})
          end
        end

        #   trigger_variables = {:dashboard_api_host_port => @config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @config[:cross_cloud_yml]}
        #   project_id =  all_gitlab_projects.select {|agp| agp["name"].downcase == name}.first["id"]
        #
        #   ["stable_ref", "head_ref"].each do |release_key_name|
        #     ref = @config[:projects][name][release_key_name]
        #     puts "Calling build_project(#{project_id}, #{ref}, #{trigger_variables})"
        #     #self.build_project(project_id, api_token, ref, trigger_variables)
        #     self.build_project(project_id, ref, trigger_variables)
        #   end
        # end
        #
      end



      ######################################
      ## App Deploy
      ##
      ## Required options
      ##  - project_id => gitlab id of project to deploy as an integer
      ##  - build_id => gitlab pipeline id for a project build (available in @builds)  as an integer
      ##  - provision_id => gitlab pipeline id for a kubernetes provisioning (available in @provisionings) as an integer
      ##  - cloud => the cloud to deploy to as a string
      ##  - options hash
      ##    - :chart_repo => helm chart repo
      ##   -  :dashboard_api_host_porta => dashhboard api host and port
      ##   -  :cross_cloud_yml => url to cross-cloud.yml
      def app_deploy(target_project_id, target_build_id, target_provision_id, target_cloud, options = {})
        # TODO: refactor out cloud or provision id

        ## GitLab pipeline to trigger
        # related to environment, eg. cidev, master, staging, production
        trigger_variables = {}
        trigger_project_name = "cross-project"
        trigger_project_id = project_id_by_name(trigger_project_name)
        trigger_api_token = @config[:gitlab][:pipeline][trigger_project_name][:api_token]
        trigger_ref = @config[:gitlab][:pipeline][trigger_project_name][:cross_project_ref]

        target_project_name = project_name_by_id(target_project_id)
        org_name = config[:projects][target_project_name]["project_url"].split("/")[3]

        ####################################
        # TODO: move this out
        # TODO: pull cloud from provisioning
        cross_cloud_id = project_id_by_name("cross-cloud")
        cross_cloud_api_token = @config[:gitlab][:pipeline]["cross-cloud"][:api_token]
        kubeconfig = retrieve_kubeconfig(cross_cloud_id, target_provision_id, cross_cloud_api_token, target_cloud)
        kubeconfig_base64 = Base64.encode64(kubeconfig).gsub(/[\r\n]+/, '')

        trigger_variables[:KUBECONFIG] = kubeconfig_base64
        ####################################
        #


        #@logger.debug "#{project_name} project id: #{project_id}, api token: #{api_token}, ref:#{ref}"
        @logger.debug "options var: #{options.inspect}"

        kubernetes_project_id = project_id_by_name("kubernetes")

        ## Setup Gitlab API trigger variables
        trigger_variables[:CLOUD] = target_cloud
        trigger_variables[:SOURCE] = target_build_id
        trigger_variables[:ORG] = org_name

        trigger_variables[:CHART_REPO] = options[:chart_repo] unless options[:chart_repo].nil?
        # trigger_variables[:FILTER] = options[:filter] unless options[:filter].nil?
        # trigger_variables[:LABEL_ARGS] = options[:label_args] unless options[:label_args].nil?

        trigger_variables[:PROJECT_ID] = target_project_id
        trigger_variables[:CHART] = target_project_name
        trigger_variables[:PROJECT_BUILD_PIPELINE_ID] = target_build_id
        trigger_variables[:TARGET_PROJECT_ID] = target_project_id
        trigger_variables[:TARGET_PROJECT_NAME] = target_project_name
        #trigger_variables[:TARGET_PROJECT_COMMIT_REF_NAME] = options[:project_ref] unless options[:project_ref].nil?
        #trigger_variables[:TARGET_PROJECT_COMMIT_REF_NAME] = @builds[:app_layer][2].first[1][:ref]
        
        project_build = @builds[:app_layer].select {|b| b[:pipeline_id] == target_build_id}.first
        target_project_ref = project_build[:ref]
        trigger_variables[:TARGET_PROJECT_COMMIT_REF_NAME] = target_project_ref

        trigger_variables[:DEPLOYMENT_NAME] = target_project_name

        trigger_variables[:DASHBOARD_API_HOST_PORT] = options[:dashboard_api_host_port] unless options[:dashboard_api_host_port].nil?
        trigger_variables[:CROSS_CLOUD_YML] = options[:cross_cloud_yml] unless options[:cross_cloud_yml].nil?

        gitlab_result = nil
        tries=3
        begin
          @logger.debug "Calling Gitlab API for #{target_project_name} trigger_pipeline(#{trigger_project_id}, #{trigger_api_token}, #{trigger_ref}, #{trigger_variables})"
          gitlab_result = @gitlab_proxy.trigger_pipeline(trigger_project_id, trigger_api_token, trigger_ref, trigger_variables)
          @logger.debug "gitlab proxy result: #{gitlab_result.inspect}"
        rescue Gitlab::Error::InternalServerError => e
          @logger.error "Gitlab Proxy error: #{e}"

          tries -= 1
          if tries > 0
            @logger.info "Trying to trigger pipeline for project #{project_name} again: #{project_id}, ref #{trigger_ref}"
            retry
          else
            @logger.error "Failed to trigger pipeline for project #{project_name}: #{project_id}, ref #{trigger_ref}"
            return
          end
        end

        gitlab_pipeline_id = gitlab_result.id
        # TODO make this like provisioning - remove pipline_id from start
        data = { project_name: target_project_name, ref: trigger_ref, project_id: target_project_id, pipeline_id: gitlab_pipeline_id, cloud: target_cloud} 
        @app_deploys << data
        data
      end


      # TODO: #8) implement app deploy loop
      #  - Required: config including cross-cloud config
      #  - determine active projects
      #  - call app deploy function for each active project for master and stable refs
      #  - handle retry

      ##############################################################
      ## Trigger, scheduled job and Dashboard specific methods below
      ##############################################################

      # Purpose: loop through all active projects and call build project for each
      def build_active_projects
        load_project_data
        @active_projects.each do |proj|
          name = proj[0]
          #next unless name == "linkerd"

          puts "Active project: #{name}"
          #next if name == "kubernetes"
          #next if name == "prometheus"

          @logger.debug "setting trigger variables"
          trigger_variables = {:dashboard_api_host_port => @config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @config[:cross_cloud_yml]}

          @logger.debug "setting project id"
          project_id =  all_gitlab_projects.select {|agp| agp["name"].downcase == name}.first["id"]

          ["stable_ref", "head_ref"].each do |release_key_name|
            ref = @config[:projects][name][release_key_name]
            puts "Calling build_project(#{project_id}, #{ref}, #{trigger_variables})"
            #self.build_project(project_id, api_token, ref, trigger_variables)
            self.build_project(project_id, ref, trigger_variables)
          end
        end
      end

      def load_cloud_data
        if @active_clouds.nil?
          @active_clouds = @config[:clouds].find_all {|c| c[1]["active"]}
        end
      end

      def load_project_data
        if @active_projects.nil?
          # Create hash of active projects from cross-cloud.yml data
          @active_projects = @config[:projects].select {|p| p if @config[:projects][p]["active"] == true }
        end

        if @all_gitlab_projects.nil?
          @all_gitlab_projects = @gitlab_proxy.get_projects
        end

        if @active_gitlab_projects.nil?
          @active_gitlab_projects = @all_gitlab_projects.collect do |agp|
            agp_name = agp["name"].downcase
            proj_id = agp["id"]
            if agp_name == "cross-cloud" || agp_name == "cross-project"
              puts "Creating mapping for #{agp_name}"
              @project_name_id_mapping[proj_id] = agp_name
              @project_name_id_mapping[agp_name] = proj_id
              nil
            elsif @active_projects[agp_name]
              puts "adding gitlab data to active projects for #{agp_name}"
              @active_projects[agp_name]["gitlab_data"] = agp

              @logger.debug "#{agp_name} project id: #{proj_id}"
              # Support looking up project by id
              #@project_id_by_name[p_id] = @active_projects[agp_name]
              @project_name_id_mapping[proj_id] = agp_name
              @project_name_id_mapping[agp_name] = proj_id
              agp
            end
          end.compact!
        end
      end

      def project_id_by_name(name)
        @project_name_id_mapping[name]
      end

      def project_name_by_id(project_id)
        @project_name_id_mapping[project_id]
      end

      def list_project_name_id_mapping
        @project_name_id_mapping
      end

      # TODO: retrieve latest successful build
      # args: project id, ref

      private
        attr_accessor :project_name_id_mapping
    end
  end
end

def check_required(var, msg, exitstatus)
  if var.nil? or var.empty?
    puts msg
    exit exitstatus unless exitstatus.nil?
  end
end

##############################################################################

@config = CrossCloudCI::Common.init_config

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

if @config[:gitlab][:api_token].nil?
  @logger.error "Global GitLab API token not set!"
  exit 1
end


#cross_cloud_config_url="https://gitlab.cncf.ci/cncf/cross-cloud/raw/ci-stable-v0.1.0/cross-cloud.yml"

#@c = CrossCloudCI::CiService.client(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
@c = CrossCloudCI::CiService.client(@config)
@gp = @c.gitlab_proxy


#build_project(gitlabprojects.select {|p| p["name"] == "Kubernetes"}.first["id"], @config[:gitlab][:pipeline]["kubernetes"][:api_token], @config[:projects]["kubernetes"]["stable_ref"], {:dashboard_api_host_port => @config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @config[:cross_cloud_yml]})

@c.load_project_data


# module CrossCloudCI
#   module TriggerClient
#    def self.


__END__



## TODO LATER: (AFTER ALL WORKING)
#
# TODO: refactor where some functions are... Some may be the app calling the CI functions vs in the CI module itself
#       eg. build active projects is more about the 3am trigger vs a common CI service function
#       - will need access to common config in both places
#       - need to decide on what options are passed ot CIService (eg. common config or specifc options)



      # TODO: build status loop? may not be needed for this client

      #         if [ "${JOB_STATUS}" == '"failed"' ]; then
      #             echo "$build failed"
      #             exit 1
      #         elif [ "${JOB_STATUS}" == '"canceled"' ]; then
      #             echo "$build canceled"
      #             exit 1
      #         elif [ "${JOB_STATUS}" == '"skipped"' ]; then
      #             echo "$build skipped"
      #             exit 1
      #         else
      #             continue
      #         fi




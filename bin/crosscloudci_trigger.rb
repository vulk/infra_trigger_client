lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
config_dir = File.expand_path("../../config", __FILE__)

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
      attr_accessor :projects, :active_projects,  :all_gitlab_projects, :active_gitlab_projects
      attr_accessor :builds, :builds2, :app_deploys, :provision_requests

      #def initialize(options = {})
      def initialize(config)
        @config = config
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::DEBUG

        @project_name_id_mapping = {}
        @builds = { :provision_layer => [], :app_layer => [] }
        @builds2 = []

        @gitlab_proxy = CrossCloudCI::GitLabProxy.proxy(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
        #@gitlab_proxy = CrossCloudCI::GitLabProxy.proxy(:endpoint => options[:endpoint], :api_token => options[:api_token])
      end

      def project_id_by_name(name)
        @project_name_id_mapping[name]
      end

      def project_name_by_id(project_id)
        @project_name_id_mapping[project_id]
      end

      def build_project(project_id, ref, options = {})
        project_name = project_name_by_id(project_id)

        @logger.debug "setting api token for #{project_name}"
        api_token = @config[:gitlab][:pipeline][project_name][:api_token]

        trigger_variables = {}

        @logger.debug "#{project_name} project id: #{project_id}, api token: #{api_token}, ref:#{ref}"
        @logger.debug "options var: #{options.inspect}"

        trigger_variables[:DASHBOARD_API_HOST_PORT] = options[:dashboard_api_host_port] unless options[:dashboard_api_host_port].nil?
        trigger_variables[:CROSS_CLOUD_YML] = options[:cross_cloud_yml] unless options[:cross_cloud_yml].nil?

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

        build_id = gitlab_result.id
        build_data = {gitlab_result.id => { project_name: project_name, ref: ref, project_id: project_id, build_id: build_id } }
        if @config[:projects][project_name]["app_layer"]
          @builds[:app_layer] << build_data
        else
          @builds[:provision_layer] << build_data
        end
        #@builds2 << CrossCloudCI::CiService::Build.new(project_id, build_id, project_name, ref)
        build_data
      end

      def get_project_names
        @gitlab_proxy.get_project_names
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
      #  - store kubernetes

      def provision_cloud(cloud, options = {})
        trigger_variables = {}

        # GitLab pipeline to trigger
        project_name = "cross-cloud"
        project_id = project_id_by_name("cross-cloud")
        # related to environment, eg. cidev, master, staging, production
        trigger_ref = options[:provision_ref]

        api_token = options[:api_token]

        #@logger.debug "#{project_name} project id: #{project_id}, api token: #{api_token}, ref:#{ref}"
        @logger.debug "options var: #{options.inspect}"

        trigger_variables[:CLOUD] = cloud

        kubernetes_project_id = project_id_by_name("kubernetes")

        trigger_variables[:SOURCE] = options[:kubernetes_build_id] unless options[:kubernetes_build_id].nil?
        trigger_variables[:PROJECT_ID] = kubernetes_project_id
        trigger_variables[:PROJECT_BUILD_PIPELINE_ID] = options[:kubernetes_build_id] unless options[:kubernetes_build_id].nil?

        trigger_variables[:TARGET_PROJECT_ID] = kubernetes_project_id
        trigger_variables[:TARGET_PROJECT_NAME] = "kubernetes"
        trigger_variables[:TARGET_PROJECT_COMMIT_REF_NAME] = options[:kubernetes_ref] unless options[:kubernetes_ref].nil?

        trigger_variables[:DASHBOARD_API_HOST_PORT] = options[:dashboard_api_host_port] unless options[:dashboard_api_host_port].nil?
        trigger_variables[:CROSS_CLOUD_YML] = options[:cross_cloud_yml] unless options[:cross_cloud_yml].nil?

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
            @logger.info "Trying to trigger pipeline for project #{project_name} again: #{project_id}, ref #{ref}"
            retry
          else
            @logger.error "Failed to trigger pipeline for project #{project_name}: #{project_id}, ref #{ref}"
            return
          end
        end

 
      end



      # TODO: #6) implement cloud provision loop for all active clouds
      #  - Required: config including cross-cloud config
      #  - determine active clouds
      #  - call provisioning function for each active cloud for master and stable refs
      #  - handle retry


      def provision_active_clouds
        active_clouds=[]
        active_clouds.each do |c|
          self.provision_cloud("aws", {:kubernetes_build_id => 1, :kubernetes_ref => "v1.8.1", :dashboard_api_host_port => "devapi.cncf.ci", :cross_cloud_yml => @c.config[:cross_cloud_yml], :api_token => @c.config[:gitlab][:pipeline]["cross-cloud"][:api_token], :provision_ref => @c.config[:gitlab][:pipeline]["cross-cloud"][:cross_cloud_ref]})
        end
      end

      # TODO: #7) implement app deploy function
      #  - Decide how to handle build artifacts not being available, options:
      #    1. don't handle it, expecting the caller to check for artifacts
      #    2. return/raise error if build artifacts are not available
      #    3. call build artifact function
      #  - review app deploy script
      #  - Required: build artifacts / build pipeline id, cloud, project, project ref

      # TODO: #8) implement app deploy loop
      #  - Required: config including cross-cloud config
      #  - determine active projects
      #  - call app deploy function for each active project for master and stable refs
      #  - handle retry


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

      def list_project_name_id_mapping
        @project_name_id_mapping
      end

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
#

@config = CrossCloudCI::Common.init_config

#cross_cloud_config_url="https://gitlab.cncf.ci/cncf/cross-cloud/raw/ci-stable-v0.1.0/cross-cloud.yml"

#@c = CrossCloudCI::CiService.client(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
@c = CrossCloudCI::CiService.client(@config)
@gp = @c.gitlab_proxy


#build_project(gitlabprojects.select {|p| p["name"] == "Kubernetes"}.first["id"], @config[:gitlab][:pipeline]["kubernetes"][:api_token], @config[:projects]["kubernetes"]["stable_ref"], {:dashboard_api_host_port => @config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @config[:cross_cloud_yml]})


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



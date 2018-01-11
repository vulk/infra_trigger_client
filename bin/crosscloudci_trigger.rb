lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
config_dir = File.expand_path("../../config", __FILE__)

require 'faraday'
require 'gitlab/gitlab_proxy'
require_relative "#{config_dir}/environment"

module CrossCloudCI
  module CiService
    def self.client(options = {})
      CrossCloudCI::CiService::Client.new(options)
    end
  end
end

module CrossCloudCI
  module CiService
    class Client
      attr_accessor :gitlab_proxy
      attr_accessor :projects
      attr_accessor :all_gitlab_projects

      def initialize(options = {})
        @gitlab_proxy = CrossCloudCI::GitLabProxy.proxy(:endpoint => options[:endpoint], :api_token => options[:api_token])
      end

  # BUILD_project () {
  #     for project in ${PROJECT_BUILDS}; do
  #         eval local project_id=\"\$PROJECT_ID_${project}\"
  #         eval local token=\"\$TOKEN_${project}\"
  #         eval local ref=\"\$REF_${project}\"
  # # Trigger Stable/Master Builds
  #         local BUILD=$(curl -X POST -F token="$token" -F ref="$ref" -F "variables[DASHBOARD_API_HOST_PORT]="${DASHBOARD_API_HOST_PORT}"" -F "variables[CROSS_CLOUD_YML]="${CROSS_CLOUD_YML}"" "$BASE_URL/api/v4/projects/$project_id/trigger/pipeline" | jq '.id')
  #         
  #         BUILD_ids "$project" "$BUILD" "$project_id"
  #         #_BUILD_IDS[$project]="$project" "$BUILD" "$project_id"
  #
  #     done
  # }
      def build_project(project_id, api_token, ref, options = {})
        # project_id = options[:project_id]
        # api_token = options[:api_token]
        # ref = options[:ref]

        trigger_variables = {}

        require 'pp'
        pp project_id, api_token, ref
        pp options
        trigger_variables[:DASHBOARD_API_HOST_PORT] = options[:dashboard_api_host_port] unless options[:dashboard_api_host_port].nil?
        trigger_variables[:CROSS_CLOUD_YML] = options[:cross_cloud_yml] unless options[:cross_cloud_yml].nil?

        puts "okay"

        puts "trigger_pipeline(#{project_id}, #{api_token}, #{ref}, #{trigger_variables})"
        @gitlab_proxy.trigger_pipeline(project_id, api_token, ref, trigger_variables)
      end

      def get_project_names
        @gitlab_proxy.get_project_names
      end


  # BUILD_status () {
  #     local build="$1"
  #     local pipeline_id="$2"
  #     local project_id="$3"
  #     echo "$build $pipeline_id"
  #     until [ "${JOB_STATUS}" == '"success"' ]; do
  #         local JOB_STATUS="$(curl -s --header "PRIVATE-TOKEN:${TOKEN}" "${BASE_URL}/api/v4/projects/${project_id}/pipelines/${pipeline_id}/jobs" | jq '.[] | select(.name=="container") | .status')"
  #         sleep 5
  #         echo waiting for "$build $pipeline_id $project_id"
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
  #     done
  #     echo "$build $pipeline_id Build Sucessfull calling project deploys"
  # }

      # def build_status
      # end

  # BUILD_ids () {
  #     local build=$1
  #     local pipeline_id=$2
  #     local project_id=$3
  #         BUILD_status "$build" "$pipeline_id" "$project_id" &
  # }

     # def build_ids
     # end

  #
  # if [ "$BASH_SOURCE" = "$0" ] ; then
  #     #Script is being run directly.  Starting project build
  #     BUILD_project
  # fi
  #

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


@c = CrossCloudCI::CiService.client(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
@gp = @c.gitlab_proxy


all_gitlab_projects = @gp.get_projects


#def build_active_projects
  if @active_projects.nil?
    @active_projects = @config[:projects].select {|p| p if @config[:projects][p]["active"] == true }
  end
  @active_projects.each do |proj|
    name = proj[0]
    puts "Active project: #{name}"
    #next if name == "kubernetes"
    next if name == "prometheus"

    trigger_variables = {:dashboard_api_host_port => @config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @config[:cross_cloud_yml]}

    project_id =  all_gitlab_projects.select {|agp| agp["name"].downcase == name}.first["id"]
    api_token = @config[:gitlab][:pipeline][name][:api_token]

    ["stable_ref", "head_ref"].each do |release_key_name|
      ref = @config[:projects][name][release_key_name]
      puts "Calling build_project(#{project_id}, #{api_token}, #{ref}, #{trigger_variables})"
      @c.build_project(project_id, api_token, ref, trigger_variables)
    end
  end
#end


#build_project(gitlabprojects.select {|p| p["name"] == "Kubernetes"}.first["id"], @config[:gitlab][:pipeline]["kubernetes"][:api_token], @config[:projects]["kubernetes"]["stable_ref"], {:dashboard_api_host_port => @config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @config[:cross_cloud_yml]})


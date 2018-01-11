lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
config_dir = File.expand_path("../../config", __FILE__)

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


@config = CrossCloudCI::Common.init_config

#@g = CrossCloudCI::GitLabProxy.proxy(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
@c = CrossCloudCI::CiService.client(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
@gp = @c.gitlab_proxy

#puts @g.get_project_names

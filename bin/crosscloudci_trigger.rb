lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
config_dir = File.expand_path("../../config", __FILE__)

#require 'pry'
require 'byebug'
require 'logger'
require 'date'
require 'yaml/store'

# CrossCloudCI::Common.init_config defined here
require_relative "#{config_dir}/environment"
require 'crosscloudci/ciservice_client'

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@config = CrossCloudCi::Common.init_config

if @config[:gitlab][:api_token].nil?
  @logger.error "Global GitLab API token not set!"
  exit 1
end

if ENV["CROSS_CLOUD_CI_ENV"]
  ci_env = ENV["CROSS_CLOUD_CI_ENV"]
else
  ci_env = "development"
end

# dt = DateTime.now.strftime("%Y%m%d-%H:%M:%S%z")
# store_file = "db/datastore-#{ci_env}-#{dt}.yml"

#store_file = "db/datastore-cidev-20180124-02:59:26-0500.yml"
store_file = "db/datastore-production-20180124-03:07:35-0500.yml"
data_store = YAML::Store.new(store_file)

#@c = CrossCloudCI::CiService.client(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
@c = CrossCloudCI::CiService.client(@config)
#@gp = @c.gitlab_proxy


#build_project(gitlabprojects.select {|p| p["name"] == "Kubernetes"}.first["id"], @config[:gitlab][:pipeline]["kubernetes"][:api_token], @config[:projects]["kubernetes"]["stable_ref"], {:dashboard_api_host_port => @config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @config[:cross_cloud_yml]})

#@c.load_project_data

###############################################################
## Steps for 3am scheduler
###############################################################

## 1. Build all projects

# Start builds and store data
# data_store.transaction do
#   @c.build_active_projects
#   data_store[:builds] = @c.builds
# end

# Load previous build data
@c.builds = data_store.transaction { data_store.fetch(:builds, {}) }

## 2. Wait for a kubernetes build to complete
#  Happy path:
#     if success for both master/head continue
#     if fail, cancelled or skip exit?

active_k8s_builds=@c.builds[:provision_layer].count
while active_k8s_builds > 0
  @c.builds[:provision_layer].each do |b|
    b[:pipeline_status] = @c.build_status(b[:project_id],b[:pipeline_id])
    @logger.debug "[Build] #{b[:project_name]} pipeline #{b[:pipeline_id]} status: #{b[:pipeline_status]}"
    # next if b[:pipeline_status] == "running"

    case b[:pipeline_status]
    when "created","running",nil
      next
    end
    active_k8s_builds -= 1
  end
  sleep 10 #if active_k8s_builds > 0
end

## 3. Provision kubernetes to all active clouds
#
# TODO: skip a provisioning a K8s if it fails to build

# data_store.transaction do
#   @c.provision_active_clouds
#   # TODO: pull pipeline id for clouds just provisioned
#   data_store[:provisionings] = @c.provisionings
# end

# Load previous provisioning data
@c.provisionings = data_store.transaction { data_store.fetch(:provisionings, []) }

## 4. Wait for Kubernetes to complete provisioning on active couds
#
#  TODO: update provision all to skip kubernetes that failed to build eg. stable build was sucess but master failed

#latest_k8s_builds = @builds[:provision_layer].sort! {|x,y| x[:pipeline_id] <=> y[:pipeline_id]}.slice(-2,2)

active_provisionings=@c.provisionings.count
while active_provisionings > 0
  @c.provisionings.each do |p|
    #p[:pipeline_status] = @c.build_status(p[:project_id],p[:pipeline_id])
    p[:pipeline_status] = @c.provision_status(p[:pipeline_id])
    @logger.debug "[Provisioning] #{p[:project_name]} pipeline #{p[:pipeline_id]} status: #{p[:pipeline_status]}"
    case p[:pipeline_status]
    when "created","running",nil
      next
    end
    # next if p[:pipeline_status] == "running"
    active_provisionings -= 1
  end
  sleep 10 #if active_provisionings > 0
end


## 5. Deploy all active Apps to active clouds
#
# TODO: skip release (eg. master/head) where kubernetes failed to build?
# TODO: skip projects that failed to build
# TODO: skip clouds that had a failed provision

active_app_builds=@c.builds[:app_layer].count
while active_app_builds > 0
  @c.builds[:app_layer].each do |b|
    b[:pipeline_status] = @c.build_status(b[:project_id],b[:pipeline_id])
    @logger.debug "[Builds] #{b[:project_name]} pipeline #{b[:pipeline_id]} status: #{b[:pipeline_status]}"

    case b[:pipeline_status]
    when "created","running",nil
      next
    end
    active_app_builds -= 1
  end
  sleep 10 #if active_app_builds > 0
end

data_store.transaction do
  #@c.app_deploy_to_active_clouds
  @c.app_deploy_to_active_clouds({release_types: [:stable]})

  data_store[:app_deploys] = @c.app_deploys
end



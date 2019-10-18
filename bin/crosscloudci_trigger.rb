#!/usr/bin/env ruby

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'byebug'
require 'logger'
require 'date'
require 'fileutils'
require 'yaml/store'
require 'crosscloudci/trigger_client'

if ENV["CROSS_CLOUD_CI_ENV"]
  ci_env = ENV["CROSS_CLOUD_CI_ENV"]
else
  ci_env = "development"
end

#dt = DateTime.now.strftime("%Y%m%d-%H:%M:%S%z")
#store_file = "db/datastore-#{ci_env}-#{dt}.yml"
@store_file = "db/datastore-#{ci_env}.yml"
#store_file = "db/datastore-cidev-20180124-02:59:26-0500.yml"
#store_file = "db/datastore-production-20180124-03:07:35-0500.yml"

def backup_datastore
  dt = DateTime.now.strftime("%Y%m%d-%H:%M:%S%z")
  ci_env = ENV["CROSS_CLOUD_CI_ENV"] ||= ""

  require 'securerandom'
  backup_file_name = "datastore-#{ci_env}-#{dt}-#{SecureRandom.hex(16)}.yml"

  cache_dir = File.join(File.expand_path('../../db', __FILE__), "cache")
  FileUtils.mkdir_p(cache_dir)

  backup_file_path = File.join(cache_dir, backup_file_name)

  backupfile = File.open(backup_file_path, "w")
  dsf = File.open(File.expand_path(@tc.data_store.path), "r")

  FileUtils.copy_stream(dsf, backupfile)
  backupfile.close
  dsf.close
  @logger.info "[TriggerClient] Backed up data store to #{backup_file_path}"
end

def trigger_help
  puts <<-EOM
# Methods for Trigger Client
## Build
# Build all active projects
\@tc.build_projects

# Build stable release for all active projects
\@tc.build_projects({release_types: [:stable]})

# Load build data from cache
\@tc.load_previous_builds

# Build a single project

## Provision (eg. K8s deploy)
# Provision (deploy kubernetes) to all active clouds
#
\@tc.provision_clouds

# Provision a single cloud

## App Deploy (eg. Apps deployed onto K8s)
# Deploy apps to active-provisioned clouds
#
\@tc.deploy_apps # head and stable
\@tc.deploy_apps({release_types: [:stable]}) # only stable releases

## Deprovision (eg. destroy the kubernetes environment on a cloud)

\@tc.deprovision_clouds
\@tc.ciservice.deprovision_cloud(provision_id)
EOM
end

def welcome_message
  <<-EOM
==================================================
= Cross-Cloud CI Trigger Client"
==================================================
*Quick start => type default_connect*

To use defaults and get a client run: default_connect
- @tc is the trigger client.
- @c is the ciservice client (also @tc.ciservice)
  => Use @c as outlined in docs/usage_from_irb.mkd 

## Manual setup
To change the data store, set the @store_file variable to use a differnt store file (default: db/datastore-<CROSS_CLOUD_CI_ENV>.yml)
Trigger client can be created with @tc = CrossCloudCi::TriggerClient.new({store_file: @store_file})
Ci service client is available as @tc.ciservice and @c
Set debugging level with @tc.logger.level and @tc.ciservice.logger.level

## Type trigger_help for more
EOM
end

def default_connect
  @tc = CrossCloudCi::TriggerClient.new({store_file: @store_file})
  @tc.logger = Logger.new(STDOUT)
  @tc.logger.level = Logger::DEBUG

  @logger.info "[TriggerClient] Dashboard API: #{@tc.config[:dashboard][:dashboard_api_host_port]}"

  @c = @tc.ciservice
  @c.logger = Logger.new(STDOUT)
  @c.logger.level = Logger::DEBUG
end

def deploy_apps
  default_connect unless @tc
  @tc.deploy_apps
end

def provision_clouds
  default_connect unless @tc
  @tc.provision_clouds
end

def sync_k8s_nightly_build
  default_connect unless @tc
  @tc.sync_k8s_nightly_build
end



def build_projects
  default_connect unless @tc
  @tc.build_projects
end


def build_and_deploy_all_projects
  default_connect unless @tc

  ###############################################################
  ## Build, provision and deploy steps
  ###############################################################

  ## 1. Build all projects

  # Build all active projects
  @tc.build_projects
  # Build stable release for all active projects
  #@c.build_projects({release_types: [:stable]})

  # Load build data from cache
  #@tc.load_previous_builds

  ## 2. Wait for a kubernetes build to complete
  #  Happy path:  continue no matter the status for both master/head continue (hoping/expecting success)

  @tc.wait_for_kubernetes_builds({status_check_interval: 30})

  sleep 10

  ## 3. Provision kubernetes to all active clouds
  # TODO: skip a provisioning a K8s if it fails to build

  @tc.provision_clouds

  #@tc.load_previous_provisions
 
  ## 4. Wait for Kubernetes to complete provisioning on active couds
  #
  #  TODO: update provision all to skip kubernetes that failed to build eg. stable build was sucess but master failed

  @tc.wait_for_kubernetes_provisionings({status_check_interval: 30})
  @tc.wait_for_app_builds({status_check_interval: 30})

  ## 5. Deploy all active Apps to active clouds
  #
  # TODO: skip release (eg. master/head) where kubernetes failed to build?
  # TODO: skip projects that failed to build
  # TODO: skip clouds that had a failed provision

  @tc.deploy_apps

  # @tc.load_previous_app_deploys

  @tc.wait_for_app_deploys({status_check_interval: 30})

  ## Cleanup resources
  @tc.deprovision_clouds
end

def build_project(project_name, ref_name)
  if project_name.nil? or ref_name.nil?
    puts "Error: project name and ref required!"
    return nil
  end

  project_id = @tc.ciservice.project_id_by_name(project_name)

  opts = {:dashboard_api_host_port => @tc.config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @tc.config[:cross_cloud_yml]}

  @tc.ciservice.build_project(project_id, ref_name, opts)
end

def deploy_k8s(ref_name, cloud)
  build_info = build_project("kubernetes", ref_name)
  pipeline_id = build_info[:pipeline_id]

  # TODO: wait for build to complete for k8s

  @tc.ciservice.provision_cloud(cloud,
                                { kubernetes_build_id: pipeline_id,
                                  kubernetes_ref: ref_name,
                                  dashboard_api_host_port: @c.config[:dashboard][:dashboard_api_host_port],
                                  cross_cloud_yml: @c.config[:cross_cloud_yml],
                                  :api_token => @c.config[:gitlab][:pipeline]["cross-cloud"][:api_token],
                                  provision_ref: @c.config[:gitlab][:pipeline]["cross-cloud"][:cross_cloud_ref]
                                }
                               ) 
end

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@logger.info "Environment: #{ENV['CROSS_CLOUD_CI_ENV']}"

if $0 == "irb"
  puts welcome_message
  puts "Environment: #{ENV['CROSS_CLOUD_CI_ENV']}" unless ENV['CROSS_CLOUD_CI_ENV'].nil?
else
  default_connect
  case ARGV[0]
  when "run_all","runall","build_and_deploy"
    @logger.info "[TriggerClient] Building and deploying everything"
    build_and_deploy_all_projects
  when "build_and_provision"
    @logger.info "[TriggerClient] Building active projects"
    @tc.build_projects
    @logger.info "[TriggerClient] Provisioning active clouds"
    @tc.provision_clouds
  when "build"
    @logger.info "[TriggerClient] Building active projects"
    @tc.build_projects
  when "provision"
    @logger.info "[TriggerClient] Provisioning active clouds"
    @tc.load_previous_builds
    @tc.provision_clouds
  when "app_deploy"
    @logger.info "[TriggerClient] Provisioning active clouds"
    @tc.load_previous_builds
    @tc.load_previous_provisions
    @tc.deploy_apps
  when "test:dataload"
    @logger.info "[TriggerClient] Testing data load from cache then exiting"
    @tc.load_previous_builds
    @tc.load_previous_provisions
    @tc.load_previous_app_deploys
    exit 0
  else
    @logger.info "[TriggerClient] Not sure what to do, so I'll just backup the data store :)"
  end

  backup_datastore
end

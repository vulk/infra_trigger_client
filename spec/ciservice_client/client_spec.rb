require './lib/crosscloudci/ciservice_client/client'
RSpec.describe CrossCloudCI::CiService do
 context "build_active_projects" do
   it "should have a valid arm array" do
     config = CrossCloudCi::Common.init_config
     client = CrossCloudCI::CiService::Client.new(config)
     gitlab_proxy = double()
     client.gitlab_proxy = gitlab_proxy
     allow(gitlab_proxy).to receive(:trigger_pipeline) do 
       a = Object.new 
       class << a  
         attr_accessor :id  
       end  
       a.id = 1
       a
     end
     expect(gitlab_proxy).to receive(:trigger_pipeline)
     data = client.build_active_projects
     expect(data["kubernetes"]["arch"]).to eq ["amd64", "arm64"]
   end
 end
 context "build_project" do
   it "should have a valid arm response" do
     config = CrossCloudCi::Common.init_config
     client = CrossCloudCI::CiService::Client.new(config)
     gitlab_proxy = double()
     client.gitlab_proxy = gitlab_proxy
     allow(gitlab_proxy).to receive(:trigger_pipeline) do 
       a = Object.new 
       class << a  
         attr_accessor :id  
       end  
       pipeline_id = 1
       a.id = pipeline_id 
       a
     end
     expect(gitlab_proxy).to receive(:trigger_pipeline)
     name = "coredns" 
     k8s = client.all_gitlab_projects.find{|x| x["name"].downcase == name}
     project_id = k8s["id"]
     ref = config[:projects][name]["head_ref"]
     options = {:dashboard_api_host_port => config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => config[:cross_cloud_yml]}
     options[:arch] = "arm64" 
     # build_project(9, master, {:dashboard_api_host_port=>"https://devapi.cncf.ci", :cross_cloud_yml=>"https://raw.githubusercontent.com/crosscloudci/cncf-configuration/master/cross-cloud.yml", :arch=>"arm64"})
     data = client.build_project(project_id, ref, options)
     # {:project_name=>"kubernetes", :ref=>"master", :project_id=>14, :pipeline_id=>1, :arch=>"arm64"}    
     expect(data[:arch]).to eq "arm64"
     pipeline_id = 1
     expect(data[:pipeline_id]).to eq pipeline_id 
     build = client.builds[:app_layer].find{|x| x[:project_name] == name}
     expect(build[:arch]).to eq "arm64" 
   end
 end
 context "provision_active_clouds" do
   it "should accept arm builds" do
     #######
     # builds
     # ####
     config = CrossCloudCi::Common.init_config
     client = CrossCloudCI::CiService::Client.new(config)
     gitlab_proxy = double()
     client.gitlab_proxy = gitlab_proxy
     allow(gitlab_proxy).to receive(:trigger_pipeline) do 
       a = Object.new 
       class << a  
         attr_accessor :id  
       end  
       a.id = 1
       a
     end
     expect(gitlab_proxy).to receive(:trigger_pipeline)
     data = client.build_active_projects
     expect(data["kubernetes"]["arch"]).to eq ["amd64", "arm64"]
     #######
     
     provision_data = client.provision_active_clouds
     expect(provision_data[0][1]["active"]).to eq true 
   end
 end
 context "provision_cloud" do
   it "should accept arm provisions" do
     #######
     # builds
     # ####
     config = CrossCloudCi::Common.init_config
     client = CrossCloudCI::CiService::Client.new(config)
     gitlab_proxy = double()
     client.gitlab_proxy = gitlab_proxy
     allow(gitlab_proxy).to receive(:trigger_pipeline) do 
       a = Object.new 
       class << a  
         attr_accessor :id  
       end  
       a.id = 1
       a
     end
     expect(gitlab_proxy).to receive(:trigger_pipeline)
     data = client.build_active_projects
     expect(data["kubernetes"]["arch"]).to eq ["amd64", "arm64"]
     #######
    
     cloud_name = 'packet' 
     latest_k8s_builds = client.builds[:provision_layer].sort! {|x,y| x[:pipeline_id] <=> y[:pipeline_id]}
     kubernetes_stable = latest_k8s_builds.find {|b| b[:ref] != "master" && b[:arch] == "arm64" }
     build_id = kubernetes_stable[:pipeline_id] 
     ref = kubernetes_stable[:ref]
     options = {}
     options = {
       dashboard_api_host_port: client.config[:dashboard][:dashboard_api_host_port],
       cross_cloud_yml: client.config[:cross_cloud_yml], 
       kubernetes_build_id: build_id,
       kubernetes_ref: ref,
       api_token: client.config[:gitlab][:pipeline]["cross-cloud"][:api_token],
       provision_ref: client.config[:gitlab][:pipeline]["cross-cloud"][:cross_cloud_ref],
     }
     options[:arch] = kubernetes_stable[:arch]
     data = client.provision_cloud(cloud_name, options)
     expect(data[:arch]).to eq "arm64" 
   end
 end
 context "app_deploy_to_active_clouds" do
   it "should accept arm provisions" do
     #######
     # builds
     # ####
     config = CrossCloudCi::Common.init_config
     client = CrossCloudCI::CiService::Client.new(config)
     gitlab_proxy = double()
     client.gitlab_proxy = gitlab_proxy
     allow(gitlab_proxy).to receive(:trigger_pipeline) do 
       a = Object.new 
       class << a  
         attr_accessor :id  
       end  
       a.id = 1
       a
     end
     expect(gitlab_proxy).to receive(:trigger_pipeline)
     data = client.build_active_projects
     expect(data["kubernetes"]["arch"]).to eq ["amd64", "arm64"]
     ######
     # provisions
     ###### 
     provision_data = client.provision_active_clouds
     expect(provision_data[0][1]["active"]).to eq true 
     allow(gitlab_proxy).to receive(:get_pipeline_jobs).with(any_args) do 
       a = {"id" =>  1,
            "name" => "Provisioning"}
       [a]
     end
     ######
     # deploys
     ###### 
     deploy_data = client.app_deploy_to_active_clouds
     expect(deploy_data).to eq true 
   end
 end
 context "app_deploy" do
   it "should accept arm provisions" do
# [App Deploy] coredns (9) v1.5.0 {}
# I, [2019-05-10T09:02:05.036721 #12305]  INFO -- : [App Deploy] Active cloud: packet
# I, [2019-05-10T09:02:05.036776 #12305]  INFO -- : [App Deploy] Deploying to packet running Kubernetes v1.13.0 provisioned in pipeline 42002 arch: 
# I, [2019-05-10T09:02:05.036834 #12305]  INFO -- : [App Deploy] self.app_deploy(9, 41990, 42002, packet, {:release_types=>[:stable, :head]})
# I, [2019-05-10T09:02:05.036889 #12305]  INFO -- : [App Deploy] Deploying to packet running Kubernetes v1.13.0 provisioned in pipeline 42003 arch: 
# I, [2019-05-10T09:02:05.036948 #12305]  INFO -- : [App Deploy] self.app_deploy(9, 41990, 42003, packet, {:release_types=>[:stable, :head]})
# I, [2019-05-10T09:02:05.037137 #12305]  INFO -- : [App Deploy] Deploying to packet running Kubernetes master provisioned in pipeline 42004 arch: 
# I, [2019-05-10T09:02:05.037210 #12305]  INFO -- : [App Deploy] self.app_deploy(9, 41990, 42004, packet, {:release_types=>[:stable, :head]})
# I, [2019-05-10T09:02:05.037282 #12305]  INFO -- : [App Deploy] Deploying to packet running Kubernetes master provisioned in pipeline 42005 arch: 
# I, [2019-05-10T09:02:05.037343 #12305]  INFO -- : [App Deploy] self.app_deploy(9, 41990, 42005, packet, {:release_types=>[:stable, :head]})
     # project_id = 
     #   project_build_id =
     #   pipeline_id =
     #   cloud_name
     # options
     # name = "coredns" 
     # k8s = client.all_gitlab_projects.find{|x| x["name"].downcase == name}
     # project_id = k8s["id"]
     # ref = config[:projects][name]["head_ref"]
     # options = {:dashboard_api_host_port => config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => config[:cross_cloud_yml]}
     # options[:arch] = "arm64" 
     #   project_build_id =
     # # {:project_name=>"kubernetes", :ref=>"master", :project_id=>14, :pipeline_id=>1, :arch=>"arm64"}    
   end
 end
end 

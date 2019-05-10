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
     k8s_build = client.builds[:app_layer].find{|x| x[:project_name] == name}
     expect(k8s_build[:arch]).to eq "arm64" 
   end
 end
 context "provision_active_clouds" do
   it "should have a valid arm response" do
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
     puts provision_data
     expect(provision_data[0][1]["active"]).to eq true 
   end
 end
end 

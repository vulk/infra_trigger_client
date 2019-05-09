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
end 

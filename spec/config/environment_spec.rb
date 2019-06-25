require './config/environment'
RSpec.describe CrossCloudCi::Common do
 context "init_config" do
   it "should initialize the yaml" do
      config = CrossCloudCi::Common.init_config
      expect(config[:projects]["kubernetes"]["head_ref"]).to eq "master"
   end

   it "should have an arch array with arm" do
      config = CrossCloudCi::Common.init_config
      expect(config[:projects]["kubernetes"]["arch"]).to eq ["amd64", "arm64"] 
   end

   it "should overwrite cross_cloud.yml with cncnfci.yml" do
      config = CrossCloudCi::Common.init_config
      expect(config[:projects]["coredns"]["arch"]).to eq ["amd64", "arm64"] 
   end

   it "should overwrite configuration_repo cross_cloud.yml with cncnfci.yml" do
      config = CrossCloudCi::Common.init_config
      expect(config[:projects]["coredns"]["configuration_repo"]).to eq "https://raw.githubusercontent.com/crosscloudci/coredns-configuration" 
   end

   it "should overwrite configuration_repo_path cross_cloud.yml with cncnfci.yml" do
      config = CrossCloudCi::Common.init_config
      expect(config[:projects]["coredns"]["configuration_repo_path"]).to eq "https://raw.githubusercontent.com/crosscloudci/coredns-configuration/master/cncfci.yml" 
   end
   ## crosscloudci/crosscloudci#103
   it "should overwrite cross_cloud.yml with release details in project configuration" do
      config = CrossCloudCi::Common.init_config
      expect(config[:projects]["prometheus"]["stable_ref"]).to eq "v2.10.0"
      expect(config[:projects]["prometheus"]["head_ref"]).to eq "master"
   end
 end
end 

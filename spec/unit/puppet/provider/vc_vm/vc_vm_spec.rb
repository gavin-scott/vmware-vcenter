require "spec_helper"
require "yaml"
require "puppet/provider/vcenter"
require "rspec/mocks"
require "fixtures/unit/puppet/provider/vc_vm/vc_vm_fixture"
require "hashie"

describe "vm create and clone behavior testing" do
  let(:fixture) {Vc_vm_fixture.new}
  let(:provider) {fixture.provider}

  context "when vc_vm provider is created " do
    it "should have a create method defined for vc_vm" do
      expect(provider.class.instance_method(:create)).to be_truthy
    end

    it "should have a destroy method defined for vc_vm" do
      expect(provider.class.instance_method(:destroy)).to be_truthy
    end

    it "should have a exists? method defined for vc_vm" do
      expect(provider.class.instance_method(:exists?)).to be_truthy
    end

    it "should have a parent 'Puppet::Provider::Vcentre'" do
      expect(provider).to be_kind_of(Puppet::Provider::Vcenter)
    end
  end

  context "when vc_vm is created " do
    before(:each) do
      provider.expects(:vm).at_least_once.returns(nil).returns(mock("vm_object"))
      provider.expects(:cdrom_iso).returns(mock("cdrom_object"))
      provider.expects(:configure_iso)
    end

    it "should create vm  if value of operation is create" do
      provider.expects(:create_vm)

      provider.create
    end

    it "should clone vm  if value of operation is clone" do
      provider.resource[:template] = "mock_template"
      provider.expects(:clone_vm)

      provider.create
    end
  end

  context "when vc_vm calls destroy " do
    let(:destroy_task) {mock("destroy_task")}

    before(:each) do
      provider.stubs(:power_state).returns("poweredOff")
      provider.stubs(:cdrom_iso)
      provider.stubs(:nfs_vm_datastore)
    end

    it "should delete vm " do
      provider.stubs(:vm).returns(mock(:Destroy_Task => destroy_task))

      destroy_task.expects(:wait_for_completion)

      provider.destroy
    end

    it "should receive error if vm not exist" do
      provider.stubs(:vm)

      expect {provider.destroy}.to raise_error(/undefined method `Destroy_Task' for nil/)
    end
  end

  context "#is_internal_nfs_datastore?" do
    it "should return true when name starts with _nfs_asm" do
      expect(provider.is_internal_nfs_datastore?("_nfs_asm_vm1")).to be_truthy
    end

    it "should return false otherwise" do
      expect(provider.is_internal_nfs_datastore?("gs4esx2-local-storage-1")).to be_falsey
    end
  end

  context "#is_local_datastore?" do
    it "should return true for local storage" do
      expect(provider.is_local_datastore?("gs4esx2-local-storage-1")).to be_truthy
    end

    it "should return true for DAS storage" do
      expect(provider.is_local_datastore?("DAS198374")).to be_truthy
    end

    it "should return false otherwise" do
      expect(provider.is_local_datastore?("_nfs_asm_gs4vm2")).to be_falsey
    end
  end

  context "#usable_datastore?" do
    let(:datastore) {{"name" => "generic-storage-1", "summary.accessible" => true}}

    it "should return false for internal NFS datastores" do
      expect(provider.usable_datastore?(datastore.merge("name" => "_nfs_asm_vm1"))).to be_falsey
    end

    it "should return false for inaccessible datastores" do
      expect(provider.usable_datastore?(datastore.merge("summary.accessible" => false))).to be_falsey
    end

    it "should return true for remote datastores" do
      expect(provider.usable_datastore?(datastore.merge("name" => "iscsi-storage-1"))).to be_truthy
    end

    it "should return true for local datastores unless `:skip_local_datastore`" do
      provider.resource[:skip_local_datastore] = :false
      expect(provider.usable_datastore?(datastore.merge("name" => "gs4esx2-local-storage-1"))).to be_truthy
    end

    it "should return false for local datastores if `:skip_local_datastore`" do
      provider.resource[:skip_local_datastore] = :true
      expect(provider.usable_datastore?(datastore.merge("name" => "gs4esx2-local-storage-1"))).to be_falsey
    end
  end

  context "datastore sorting" do
    let(:pods) {
      [
          {"name" => "pod-storage-1",
           "pod" => true,
           "info" => mock("pod-storage-1_info"),
           "summary" => mock("pod-storage-1_summary"),
           "summary.capacity" => 591363309568,
           "summary.freeSpace" => 564766179328,
           "free" => 564766179328,
           "summary.accessible" => true},
          {"name" => "pod-storage-2",
           "pod" => true,
           "info" => mock("pod-storage-1_info"),
           "summary" => mock("pod-storage-1_summary"),
           "summary.capacity" => 591363309568,
           "summary.freeSpace" => 179328,
           "free" => 179328,
           "summary.accessible" => true}
      ]
    }

    let(:datastores) {
      [
          {"name" => "iscsi-storage-1",
           "iscsi" => true,
           "info" => mock("iscsi-storage-1_info"),
           "summary" => mock("iscsi-storage-1_summary"),
           "summary.capacity" => 591363309568,
           "summary.freeSpace" => 564766179328,
           "summary.accessible" => true},
          {"name" => "iscsi-storage-2",
           "iscsi" => true,
           "info" => mock("iscsi-storage-2_info"),
           "summary" => mock("iscsi-storage-2_summary"),
           "summary.capacity" => 591363309568,
           "summary.freeSpace" => 179328,
           "summary.accessible" => true},
          {"name" => "iscsi-storage-inaccessible",
           "iscsi" => true,
           "info" => mock("iscsi-storage-inaccessible_info"),
           "summary" => mock("iscsi-storage-inaccessible_summary"),
           "summary.capacity" => 591363309568,
           "summary.freeSpace" => 179328,
           "summary.accessible" => false},
          {"name" => "gs4esx2-local-storage-1",
           "info" => mock("gs4esx2-local-storage-1_info"),
           "summary" => mock("gs4esx2-local-storage-1_summary"),
           "summary.capacity" => 591363309568,
           "summary.freeSpace" => 564766179328,
           "summary.accessible" => true},
          {"name" => "gs4esx2-local-storage-2",
           "info" => mock("gs4esx2-local-storage-2_info"),
           "summary" => mock("gs4esx2-local-storage-2_summary"),
           "summary.capacity" => 591363309568,
           "summary.freeSpace" => 98347987,
           "summary.accessible" => true},
          {"name" => "_nfs_asm_gs5vm1",
           "info" => mock("_nfs_asm_gs5vm1_info"),
           "summary" => mock("_nfs_asm_gs5vm1_summary"),
           "summary.capacity" => 52710469632,
           "summary.freeSpace" => 45187215360,
           "summary.accessible" => false}]
    }

    context "#prioritized_datastores" do
      it "should order by pods, remote, then local datastores" do
        provider.expects(:get_cluster_storage_pods).returns(pods.sort_by {rand})

        prioritized = provider.prioritized_datastores(datastores.sort_by {rand})

        expected = (pods + datastores.reject {|d| !d["summary.accessible"]}).map {|d| d["name"]}

        expect(prioritized.map {|d| d["name"]}).to eq(expected)
      end

      it "not require pods" do
        provider.expects(:get_cluster_storage_pods).returns([])

        prioritized = provider.prioritized_datastores(datastores.sort_by {rand})

        expected = datastores.reject {|d| !d["summary.accessible"]}.map {|d| d["name"]}

        expect(prioritized.map {|d| d["name"]}).to eq(expected)
      end
    end

    context "#get_cluster_datastore" do
      let(:retriever) {mock("RetrieveProperties")}
      let(:vim) {mock(:propertyCollector => retriever)}
      let(:cluster) {mock(:datastore => [])}

      before(:each) do
        provider.stubs(:vim).returns(vim)
        provider.stubs(:cluster).returns(cluster)
      end

      it "should return the best datastore" do
        provider.resource[:datastore] = "" # pick it instead
        retriever.expects(:RetrieveProperties).returns(datastores)
        provider.expects(:get_cluster_storage_pods).returns([])

        expect(provider.get_cluster_datastore["name"]).to eq("iscsi-storage-1")
      end

      it "should return the requested datastore" do
        provider.resource[:datastore] = "gs4esx2-local-storage-1"
        retriever.expects(:RetrieveProperties).returns(datastores)
        provider.expects(:get_cluster_storage_pods).returns([])

        expect(provider.get_cluster_datastore["name"]).to eq("gs4esx2-local-storage-1")
      end

      it "should fail if the requested datastore is not found" do
        retriever.expects(:RetrieveProperties).returns(datastores)
        provider.expects(:get_cluster_storage_pods).returns([])

        expect {provider.get_cluster_datastore}.to raise_error("Datastore gale-fsr not found")
      end

      it "should fail if no datastore is big enough" do
        provider.resource[:datastore] = "" # pick it instead
        provider.resource[:virtual_disks] = [{"size" => 500000}, {"size" => 500000}]

        retriever.expects(:RetrieveProperties).returns(datastores)
        provider.expects(:get_cluster_storage_pods).returns([])

        expect {provider.get_cluster_datastore}.to raise_error("No datastore found with sufficient free space")
      end
    end
  end
end

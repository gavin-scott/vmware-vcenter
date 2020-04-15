# frozen_string_literal: true

provider_path = Pathname.new(__FILE__).parent.parent
require File.join(provider_path, 'vcenter')
require 'rbvmomi'
require 'yaml'

# rubocop:disable Metrics/BlockLength
Puppet::Type.type(:vc_vm_cpumem).provide(
  :vc_vm_cpumem,
  parent: Puppet::Provider::Vcenter
) do
  @doc = 'Reconfigure VM CPU/Memory'

  def vm
    @vm ||= findvm_by_name(datacenter.vmFolder, resource[:name])
  end

  def datacenter(name = resource[:datacenter])
    @datacenter ||=
      vim.serviceInstance.find_datacenter(name) ||
      raise(Puppet::Error, "datacenter '#{name}' not found.")
  end

  def compute_resources_configured?
    vm.config.hardware.numCPU == resource[:num_cpus] &&
      vm.config.hardware.memoryMB == resource[:memory_mb]
  end

  def vm_memory_cpu_for_svm(vm, memory_in_mb, num_cpu)
    Puppet.debug("Setting VM memory/cpus: #{memory_in_mb} MB, #{num_cpu} CPUs, and reserving guest memory...")
    config_spec = RbVmomi::VIM.VirtualMachineConfigSpec(
      memoryMB: memory_in_mb,
      numCPUs: num_cpu,
      numCoresPerSocket: num_cpu,
      memoryReservationLockedToMax: true
    )
    task = vm.ReconfigVM_Task(spec: config_spec)
    task.wait_for_completion
    raise("Failed vm configuration task for #{vm.name} with error #{task.info[:error][:localizedMessage]}") if task.info[:state] == 'error'
  end

  def configure_compute_resources
    return if compute_resources_configured?

    # Puppet.Debug(format('CPUMEM Parent: %<parent>s', parent))
    vm_memory_cpu_for_svm(
      vm,
      resource[:memory_mb],
      resource[:num_cpus]
    )
  end

  def exists?
    vm && compute_resources_configured?
  end

  def create
    # CPU and Memory resources can be configured after deployment
    # This is usually done during FlexOS GW upgrade
    # If you call this, make sure the vm is shutdown beforehand
    configure_compute_resources
  end
end
# rubocop:enable Metrics/BlockLength

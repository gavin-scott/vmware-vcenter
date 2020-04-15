# frozen_string_literal: true

require 'puppet_x/vmware/util'
require 'puppet_x/vmware/mapper'
require 'puppet/property/vmware'

# rubocop:disable Metrics/BlockLength
Puppet::Type.newtype(:vc_vm_cpumem) do
  @doc = 'Reconfigure VM CPU/Memory'

  ensurable do
    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.destroy
    end
    defaultto(:present)
  end

  newparam(:name, namevar: true) do
    desc 'The virtual machine name.'
    newvalues(/.+/)
  end

  newparam(:datacenter) do
    desc 'Name of the datacenter.'
    newvalues(/.+/)
  end

  newparam(:cluster) do
    desc 'Name of the cluster.'
  end

  newparam(:memory_mb) do
    desc 'Amount of memory to be re-assigned to the VM.'
    munge do |value|
      Integer(value)
    end
  end

  newparam(:num_cpus) do
    desc 'Number of CPUs to be re-assigned to the VM.'
    munge do |value|
      Integer(value)
    end
  end
end
# rubocop:enable Metrics/BlockLength

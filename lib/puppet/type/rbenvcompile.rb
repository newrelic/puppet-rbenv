Puppet::Type.newtype(:rbenvcompile) do
  desc 'Compile a particular Ruby version for use in RBenv'

  ensurable do
    newvalue(:present) { provider.install   }
    newvalue(:absent ) { provider.uninstall }

    aliasvalue :installed, :present

    defaultto :present

    def retrieve
      provider.current || :absent
    end

    def insync?(current)
      requested = @should.first

      case requested
      when :present, :installed
        current != :absent
      when :absent
        current == :absent
      else
        current == [requested]
      end
    end
  end

  newparam(:name, :namevar => true) do
    desc 'The catalog name'
  end

  newparam(:ruby) do
    desc 'The ruby interpreter version'
  end

  newparam(:rbenv) do
    desc 'The rbenv root'

    # Support all the goodness that expand_path supports
    # e.g. ~user for home dirs.
    munge do |value|
      File.expand_path(File.join(value, '.rbenv'))
    end
  end

  newparam(:keep_source) do
    desc 'Whether or not to keep the Ruby source after compilation'
    
    munge do |value|
      case true
      when value == false   then false
      when value == 'false' then false
      when value == true    then true
      when value == 'true'  then true
      else false
      end
    end
  end

  newparam(:user) do
    desc 'The rbenv owner'
  end
end

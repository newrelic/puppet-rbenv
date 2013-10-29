Puppet::Type.newtype(:rbenvinstall) do
  desc 'Install the RBenv base tooling to a particular path and set up for a user'

  ensurable do
    newvalue(:present) { provider.install   }
    newvalue(:absent ) { }

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

  newparam(:rbenv, :namevar => true) do
    desc 'The rbenv root'

    # Support all the goodness that expand_path supports
    # e.g. ~user for home dirs.
    munge do |value|
      File.expand_path(File.join(value, '.rbenv'))
    end
  end

  newparam(:user) do
    desc 'The rbenv owner'
  end

  newparam(:rc_file) do
    desc 'The file to source rbenv from'
    defaultto :'.profile'
  end

  newparam(:home_dir) do
    desc 'The directory where the rc_file and .rbenvrc are'
    defaultto { "~#{self[:user]}" }
  end
end

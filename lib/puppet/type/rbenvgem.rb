Puppet::Type.newtype(:rbenvgem) do
  desc 'A Ruby Gem installed inside an rbenv-installed Ruby'

  ensurable do
    newvalue(:present) { provider.install   }
    newvalue(:absent ) { provider.uninstall }

    newvalue(:latest) {
      provider.uninstall if provider.current
      provider.install
    }

    newvalue(/./)  do
      provider.uninstall if provider.current
      provider.install
    end

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
      when :latest
        current == provider.latest
      when :absent
        current == :absent
      else
        current == [requested]
      end
    end
  end

  newparam(:gem, :namevar => true) do
    desc 'The gem to install'
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

  newparam(:user) do
    desc 'The rbenv owner'
  end

  autorequire(:rbenvcompile) do
    # Autorequire rbenv compile
    if (rbenv = self[:rbenv])
      rbenv
    end
  end
end

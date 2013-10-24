Puppet::Type.type(:rbenvcompile).provide :default do
  desc 'Compile a particular Ruby version for use in RBenv'

  def install
    opts = resource[:keep_source] ? '--keep' : ''
    begin
      ENV['RUBY_BUILD_BUILD_PATH'] = Dir.mktmpdir("ruby-build.#{$$}")
      rbenv('install', opts, resource[:ruby])
    rescue Puppet::Error => e
      FileUtils.rm_rf(ENV['RUBY_BUILD_BUILD_PATH'])
      raise Puppet::Error, e.message, e.backtrace
    end
  end

  def uninstall
    rbenv('uninstall', resource[:ruby])
  end

  def current
    rbenv('versions').split(/\n/).any? { |x| x =~ /^\s*#{resource[:ruby]}/ }
  end

  private
    def sudo(args)
      args = args.join(' ')

      output = Puppet::Util::Execution.execute(
        "sudo #{args}", 
        :failonfail => false, 
        :combine => true
      )
      exitstatus = $CHILD_STATUS.exitstatus

      unless exitstatus == 0
        raise Puppet::Error.new(
          "Failure: 'sudo #{args} exitstatus': #{exitstatus}, output: '#{output}'"
        )
      end

      output
    end

    def rbenv(*args)
      exe = File.join(resource[:rbenv], *%w{ bin rbenv })
      sudo('-u', resource[:user], exe, *args)
    end
end

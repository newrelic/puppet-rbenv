Puppet::Type.type(:rbenvcompile).provide :default do

  desc 'Compile a particular Ruby version for use in RBenv'

  RUBY_BUILD_REPO = 'git://github.com/sstephenson/ruby-build.git'

  def install
    ENV['RBENV_ROOT'] = resource[:rbenv]
    ensure_ruby_build

    notice "Installing #{resource[:ruby]} at #{resource[:rbenv]}"
    opts = resource[:keep_source] ? '--keep' : ''

    ensuring_cleanup_after_build do
      ENV['RUBY_BUILD_BUILD_PATH'] = Dir.mktmpdir("ruby-build.#{$$}")
      output = rbenv('install', opts, resource[:ruby])
    end
    
    validate_install(output)
  end

  def uninstall
    rbenv('uninstall', resource[:ruby])
  end

  def current
    versions_dir = File.join(resource[:rbenv], 'versions', resource[:ruby])

    unless File.exists?(versions_dir)
      notice "#{resource[:ruby]} can't be installed, versions dir (#{versions_dir}) is missing."
      return false
    end

    ENV['RBENV_ROOT'] = resource[:rbenv]

    versions = rbenv('versions').split(/\n/)
    notice "Found installed: #{versions.join(', ')}"
    versions.any? { |x| x =~ /#{resource[:ruby]}/ }
  end

  private
    def ensuring_cleanup_after_build(&block)
      block.call
    ensure
      unless ENV['RUBY_BUILD_BUILD_PATH'].nil?
        FileUtils.rm_rf(ENV['RUBY_BUILD_BUILD_PATH'])
      end
    end

    def validate_install(output)
      # Rbenv doesn't exit non-zero when given a bad command,
      # it just shows usage output, so we check for that.
      if output =~ /rbenv commands/
        raise Puppet::Error.new('Looks like ruby-build plugin is not installed!')
      end
    end

    def su(*args)
      args = args.join(' ')

      executor = Puppet::Util::Execution.respond_to?(:execute) ? Puppet::Util::Execution : Puppet::Util
      command  = "su #{resource[:user]} -s /bin/bash -c '#{args}'"

      info "Executing: #{command}"

      output = executor.send(:execute,
        command, 
        {
          :failonfail => false, 
          :combine => true 
        }
      )
      exitstatus = $CHILD_STATUS.exitstatus

      unless exitstatus == 0
        raise Puppet::Error.new(
          "Failure: `#{command}` exitstatus: #{exitstatus}, output: '#{output}'"
        )
      end

      output
    end

    def rbenv(*args)
      su(rbenv_path, *args)
    end

    def rbenv_path
      File.join(resource[:rbenv], *%w{ bin rbenv })
    end

    def ensure_ruby_build
      plugins_dir = File.join(resource[:rbenv], 'plugins')
      return if File.exists?(File.join(plugins_dir, 'ruby-build'))

      FileUtils.mkdir_p(plugins_dir)
      FileUtils.chown_R(resource[:user], nil, resource[:rbenv])

      starting_dir = FileUtils.pwd
      FileUtils.chdir plugins_dir
      su('git clone', RUBY_BUILD_REPO)
      FileUtils.chdir starting_dir
    end
end

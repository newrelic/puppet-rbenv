class Rbenv
  def initialize(rbenv_path, user, ruby_version, logger)
    @rbenv_root   = rbenv_path
    @user         = user
    @ruby_version = ruby_version
    @logger       = logger
  end

  def versions
    versions = run('versions').split(/\n/).map { |x| x.sub(/^\s*/, '') }
    info "Found installed: #{versions.join(', ')}"
    versions
  end

  def install(version, keep_source)
    ensure_ruby_build

    info "Installing #{version} at #{@rbenv_root}"
    opts = keep_source ? '--keep' : ''

    output = ensuring_cleanup_after_build do
      ENV['RUBY_BUILD_BUILD_PATH'] = Dir.mktmpdir("ruby-build.#{$$}")
      run('install', opts, version)
    end
    
    validate_install(output)
  end

  def uninstall(version)
    run('uninstall', version)
  end

  def rehash
    run('rehash')
  end

  def run(*args)
    ENV['RBENV_ROOT'] = @rbenv_root
    su(rbenv_path, *args)
  end

  def su(*args)
    args = args.join(' ')

    command  = "RBENV_VERSION=#{@ruby_version} su #{@user} -s /bin/bash -c '#{args}'"

    info "Executing: #{command}"

    output = puppet_executor.send(:execute,
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

  private

  def info(*args)
    @logger.call(args.join(' '))
  end

  def puppet_executor
    Puppet::Util::Execution.respond_to?(:execute) ? Puppet::Util::Execution : Puppet::Util
  end

  def rbenv_path
    File.join(@rbenv_root, *%w{ bin rbenv })
  end

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

  def ensure_ruby_build
    plugins_dir = File.join(@rbenv_root, 'plugins')
    return if File.exists?(File.join(plugins_dir, 'ruby-build'))

    FileUtils.mkdir_p(plugins_dir)
    FileUtils.chown_R(@user, nil, @rbenv_root)

    starting_dir = FileUtils.pwd
    FileUtils.chdir plugins_dir
    su('git clone', RUBY_BUILD_REPO)
    FileUtils.chdir starting_dir
  end
end

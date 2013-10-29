class Rbenv

  RUBY_BUILD_REPO = 'git://github.com/sstephenson/ruby-build.git'
  RBENV_REPO      = 'git://github.com/sstephenson/rbenv.git'

  def initialize(rbenv_path, user, ruby_version, logger)
    @rbenv_root   = rbenv_path
    @user         = user
    @ruby_version = ruby_version
    @logger       = logger
  end

  def rbenv_version
    output = in_directory('/') do
      su("#{rbenv_path} -v")
    end
    info "Output: #{output}"
    output.split(/ /).last.chomp
  end

  def rbenv_install(home_dir)
    if File.exists?(File.join(@rbenv_root, 'shims'))
      notice "Skipping rbenv install at #{@rbenv_root}: already installed!"
      return
    end

    FileUtils.mkdir_p(@rbenv_root)
    FileUtils.chown_R(@user, nil, @rbenv_root)

    unless File.exists?(File.join(@rbenv_root, '.git'))
      in_directory(File.dirname(@rbenv_root)) do
        ENV['RBENV_ROOT'] = @rbenv_root
        su('git clone', RBENV_REPO, '.rbenv')
      end
    end
  end

  def rbenv_uninstall(home_dir, rc_file)
    rc_file = File.join(home_dir, rc_file)
    info "Removing rcfile: #{rc_file}"
    FileUtils.rm_f(rc_file)

    info "Removing rbenv and all Rubies at #{@rbenv}"
    FileUtils.rm_rf(@rbenv)
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
    in_directory '/' do    
      ENV['RBENV_ROOT'] = @rbenv_root
      su(rbenv_path, *args)
    end
  end

  def su(*args)
    args = args.join(' ')

    command  = "RBENV_VERSION=#{@ruby_version} su #{@user} -s /bin/bash -c '#{args}'"
    execute(command)
  end

  def create_cache_dir
    cache_dir = File.join(@rbenv_root, 'cache')
    FileUtils.mkdir_p(cache_dir)
    FileUtils.chown_R(@user, nil, cache_dir)
  end

  def setup_rc_for_user(home_dir, rc_file)
    rc_path = File.expand_path(File.join(home_dir, '.rbenvrc'))
    info "RC Path: #{rc_path}"

    return if File.exists?(rc_path)

    rbenvrc = <<-EOS.gsub(/^[ ]{6}/, '')
      #
      # This is a shell fragment that initializes rbenv, if it
      # has not been initialized yet. Managed by puppet - DO NOT EDIT
      #
      if ! echo $PATH | grep -q rbenv; then
        export PATH="#{@rbenv_root}/bin:$PATH"
        eval "$(rbenv init -)"
      fi
    EOS

    File.open(rc_path, 'wb') { |f| f.write(rbenvrc) }
    FileUtils.chown(@user, nil, rc_path)
    su("echo 'source #{rc_path}' >> #{rc_file}")
  end

  private
  
  def execute(command)
    info "Executing: '#{command}' from #{Dir.pwd} as #{Process.euid}"

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

  def in_directory(dir, &block)
    starting_dir = FileUtils.pwd
    FileUtils.chdir dir
    output = block.call
    FileUtils.chdir starting_dir
    output
  end

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
    ENV['RUBY_BUILD_BUILD_PATH'] = Dir.mktmpdir("ruby-build.#{$$}")
    FileUtils.chown(@user, nil, ENV['RUBY_BUILD_BUILD_PATH'])
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

    in_directory(plugins_dir) do
      su('git clone', RUBY_BUILD_REPO)
    end
  end
end

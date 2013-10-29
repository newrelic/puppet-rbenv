$: << File.join(File.dirname(__FILE__), *%w{.. .. .. rbenv})
require 'rbenv'

Puppet::Type.type(:rbenvinstall).provide :default do

  desc 'Install the RBenv base tooling to a particular path and set up for a user'

  def install
    rbenv.rbenv_install(resource[:home_dir])
    rbenv.setup_rc_for_user(resource[:home_dir], resource[:rc_file])
    rbenv.create_cache_dir
  end

  def current
    return false unless File.exists?(File.join(resource[:rbenv], 'bin/rbenv'))
    rbenv.rbenv_version
  end

  private

  def rbenv
    @rbenv ||= Rbenv.new(
      resource[:rbenv],
      resource[:user],
      nil,
      lambda { |line| info line }
    )
  end
end

$: << File.join(File.dirname(__FILE__), *%w{.. .. .. rbenv})
require 'rbenv'

Puppet::Type.type(:rbenvcompile).provide :default do

  desc 'Compile a particular Ruby version for use in RBenv'

  def install
    rbenv.install(resource[:ruby], resource[:keep_source])
  end

  def uninstall
    rbenv.uninstall(resource[:ruby])
  end

  def current
    versions_dir = File.join(resource[:rbenv], 'versions', resource[:ruby])
    return false unless File.exists?(versions_dir)
    rbenv.versions.any? { |x| x =~ /#{resource[:ruby]}/ }
  end

  private

  def rbenv
    @rbenv ||= Rbenv.new(
      resource[:rbenv],
      resource[:user],
      resource[:ruby],
      lambda { |line| info line }
    )
  end
end

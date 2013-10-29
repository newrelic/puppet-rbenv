$: << File.join(File.dirname(__FILE__), *%w{.. .. .. rbenv})
require 'rbenv'

Puppet::Type.type(:rbenvgem).provide :default do
  desc "Maintains gems inside an RBenv setup"

  def install
    args = ['install', '--no-rdoc', '--no-ri']
    args << "-v\"#{resource[:ensure]}\"" if !resource[:ensure].kind_of?(Symbol)
    args << gem_name

    output = gem(*args)
    fail "Could not install: #{output.chomp}" if output.include?('ERROR')
    rbenv.rehash
  end

  def uninstall
    gem 'uninstall', '-aIx', gem_name
    rbenv.rehash
  end

  def latest
    @latest ||= list(:remote)
  end

  def current
    list
  end

  private
    def rbenv
      @rbenv ||= Rbenv.new(
        resource[:rbenv],
        resource[:user] || owner_of_rbenv(resource[:rbenv]),
        resource[:ruby],
        lambda { |line| info line }
      )
    end

    def gem_name
      resource[:name]
    end

    def gem(*args)
      exe = "RBENV_VERSION=#{resource[:ruby]} " + resource[:rbenv] + '/bin/gem'
      rbenv.su(
        File.join(resource[:rbenv], 'versions', resource[:ruby], 'bin', 'gem'),
        args
      )
    end

    def list(where = :local)
      args = ['list', where == :remote ? '--remote' : '--local', "#{gem_name}$"]

      gem(*args).lines.map do |line|
        line =~ /^(?:\S+)\s+\((.+)\)/

        return nil unless $1

        # Fetch the version number
        ver = $1.split(/,\s*/)
        ver.empty? ? nil : ver
      end.first
    end

    def owner_of_rbenv(rbenv_path)
      return 'root' unless File.exists?(rbenv_path)

      require 'etc'
      uid = File.stat(rbenv_path).uid
      Etc.getpwuid(uid).name
    end
end

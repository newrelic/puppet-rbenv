# Install a gem under rbenv for a certain user's ruby version.
# Title doesn't matter, just don't duplicate it
# Requires rbenv::compile for the passed in user and ruby version
define rbenv::gem($gemname, $foruser, $rubyversion, $gemversion) {
  $gemcmd = "/home/$foruser/.rbenv/versions/$rubyversion/bin/gem"

  $ruby_version_assert = "[ -f $gemcmd ]"
  $exec_path = [ "/home/$foruser/.rbenv/shims", "/home/$foruser/.rbenv/bin", '/usr/bin', '/bin']
 
  exec {
    "install rbenv gem $gemname $gemversion in ruby $rubyversion for $foruser":
      command => "$gemcmd install $gemname --quiet --no-ri --no-rdoc --version='$gemversion'",
      path    => $exec_path,
      user    => $foruser,
      onlyif  => $ruby_version_assert,
      unless  => ["$gemcmd list -i -v'$gemversion' $gemname"],
      require => Rbenv::Compile["rbenv::compile::$foruser::$rubyversion"];
  }
}
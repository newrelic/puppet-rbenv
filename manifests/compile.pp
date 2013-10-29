# Compile and set up an rbenv-managed Ruby

define rbenv::compile(
  $user,
  $rbenv_root      = "~${user}"
  $ruby            = $title,
  $keep_source     = false,
  $bundler_version = 'latest'
) {

  if ! defined(Class['rbenv::dependencies']) {
    require rbenv::dependencies
  }
  
  $compile_name = "${user}-${rbenv_root}-${ruby}"
  $bundler_name = "bundler-${compile_name}"
  $install_name = "rbenv::install ${user}-${rbenv}"

  rbenvcompile { $compile_name:
    ensure      => present,
    ruby        => $ruby,
    rbenv       => $rbenv_root,
    keep_source => $keep_source,
    user        => $user
  }

  rbenvgem { $bundler_name:
    gem    => 'bundler',
    ensure => $bundler_version,
    ruby   => $ruby,
    rbenv  => $rbenv_root
  }

  if $global {
    $global_name = "rbenv::global-${user}-${rbenv_root}"

    file { $global_name:
      path    => $global_path,
      content => "$ruby\n",
      owner   => $user,
      group   => $group,
    }

    Rbenvcompile[$compile_name] -> File[$global_name]
  }

  Rbenv::Install[$install_name] -> Rbenvcompile[$compile_name]
  Rbenvcompile[$compile_name]   -> Rbenvgem[$bundler_name]
}

# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capistrano_chef_solo/version"

Gem::Specification.new do |s|
  s.name        = "capistrano_chef_solo"
  s.version     = CapistranoChefSolo::VERSION
  s.authors     = ["iain"]
  s.email       = ["iain@iain.nl"]
  s.homepage    = "https://github.com/iain/capistrano_chef_solo"
  s.summary     = %q{Combining the awesome powers of Capistrano and chef-solo}
  s.description = %q{This gem provides Capistrano tasks to run chef-solo with Capistrano, with hardly any configuration needed.}

  s.rubyforge_project = "capistrano_chef_solo"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "capistrano", "~> 2.8"
end

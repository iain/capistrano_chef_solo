require "capistrano_chef_solo/version"
require 'json'
require 'tempfile'

Capistrano::Configuration.instance(:must_exist).load do

  namespace :chef do

    desc <<-DESC
      Installs chef-solo and everything it needs if chef-solo hasn't been installed yet.

      This does not run any chef recipes. You need to make your own tasks and hooks for that. \
      This task will automatically run when running any chef recipes, \
      so you normally won't need to run this task yourself anyway.

      == Run lists

      You'll need to tell capistrano which recipes to run and when. \
      You can define a task for this:

        task :run_recipes do
          chef.solo "recipe[foo]", "recipe[bar]"
        end

      Or, preferrably, you can hook them up to your normal deployment proces:

        before "deploy" do
          chef.solo "recipe[foo]", "recipe[bar]"
        end

      Sometimes you need to split up your run list, because some chef recipes will fail \
      if they are run at the wrong moment. \
      For example, you need to install the database before deploying, \
      because some of your gems won't compile if you don't have the proper header files. \
      You probably want to run the apache recipe after you've completed normal deployment, \
      because it would fail if there is no current/public directory available. \
      So, for example, you can think in the lines of this setup:

        before "deploy" do
          chef.solo "recipe[myapp::mysql]"
        end

        after "deploy:symlink" do
          chef.solo "recipe[myapp::apache2]"
        end

      You'll probably wind up creating your own cookbook, so it is wise to split it up into \
      recipes that can run at the appropriate time.

      == Cookbooks

      Cookbooks are what power Chef. In order to use it, you must have some. \
      By default, Capistrano will look in `config/cookbooks` and `vendor/cookbooks`. \
      They will be copied over when you run them, so there is no need to commit and push \
      changes in your cookbooks just to try them out. \
      You don't need to specify individual cookbooks, but the directories containing them. \
      To change the location of the cookbooks:

        set :cookbooks, [ "vendor/cookbooks", "config/cookbooks" ]

      == Node attributes

      You can set node attributes by setting :chef_attributes to a hash. \
      This will be converted to JSON and fed to chef-solo.

      Example:

        set :chef_attributes, :foo => { :bar => "baz" }

      You can access these attributes from within your recipes:

        node[:foo][:bar] # => bar

      Some attributes will automatically be set with values from Capistrano:

        {
          :application  => application,
          :deploy_to    => deploy_to,
          :user         => user,
          :password     => password,
          :main_server  => main_server,
          :migrate_env  => migrate_env,
          :scm          => scm,
          :repository   => repository,
          :current_path => current_path,
          :release_path => release_path,
          :shared_path  => shared_path
        }

      These values are only set if you didn't set themself in :chef_attributes. \
      You can turn them off completely by setting :default_chef_attributes to false.

      == Streaming

      Some of the commands that are run are very long, so by default, their outputs \
      are streamed to your console (i.e. not prefixed). If you don't want that:

        set :chef_streaming, false

      == Ruby

      Ruby is a dependency of chef, so rather than installing ruby through a cookbook, \
      Capistrano needs to install Ruby before being able to install and run Chef. \
      The default Ruby is 1.9.2-p290 with some performance patches. \
      To see how to configure this, run:

        cap --explain chef:install:ruby | less


    DESC
    task :default, :except => { :no_release => true } do
      unless installed?("chef-solo")
        logger.info "Bootstrapping host to install chef-solo"
        install.default
      end
    end

    namespace :install do

      desc <<-DESC
        Install chef-solo, whether it has been installed or not.

        This will do:

        * Perform a dist-upgrade (chef:install:dist_upgrade)
        * Install the dependencies for installing Ruby (chef:install:dependencies)
        * Compile and install Ruby (chef:install:ruby)
        * Install chef (chef:install:chef)

        Be sure to check out the documentation of these tasks.
      DESC
      task :default, :except => { :no_release => true } do
        dist_upgrade
        dependencies
        ruby unless installed?("ruby")
        chef
      end

      desc "Performs a dist-upgrade on your system"
      task :dist_upgrade, :except => { :no_release => true } do
        case os
        when "ubuntu"
          stream_or_run "#{sudo} aptitude update"
          stream_or_run "#{sudo} apt-get -o Dpkg::Options::=\"--force-confnew\" --force-yes -fuy dist-upgrade"
        when "centos"
          stream_or_run "#{sudo} yum update -y"
        end
      end

      desc "Installs the dependencies to compile Ruby"
      task :dependencies, :except => { :no_release => true } do
        case os
        when "ubuntu"
          stream_or_run "#{sudo} aptitude install -y git-core curl build-essential bison openssl \
                libreadline6 libreadline6-dev zlib1g zlib1g-dev libssl-dev \
                libyaml-dev libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev \
                vim wget tree" # this line not really dependencies, but who can live without them?
        when "centos"
          stream_or_run "#{sudo} yum install -y git-core curl patch bison openssl \
                readline readline-devel zlib zlib-devel openssl-devel \
                libyaml-devel libxml2-devel libxslt-devel autoconf glibc-devel ncurses-devel \
                vim wget tree" # this line not really dependencies, but who can live without them?
        end
      end

      desc <<-DESC
        Compiles Ruby from source and applies 1.9.2 patches to speed it up.

        This usually gives a lot of output, so most of the compiling output is saved \
        to a file on the server. The path will appear in the output.

        This is done globally, by hand, because Ubuntu ships with an old Ruby version, \
        and using RVM with stuff like passenger has a bit too many caveats. \
        If this is not your cup of tea, feel free to override this task completely. \
        There are however a couple of configuration options to this method:

        == Ruby version

        It defaults to ruby-1.9.2-p290, but you can change it here.

          set :ruby_version, "ruby-1.9.2-p189"

        == The URL of the tarball

        If the Ruby version is not 1.9.x, or, if it is not hosted on ruby-lang.org, \
        you also need to set :ruby_url, to point to the url the tar-file can be downloaded. \
        You don't need to set :ruby_url, if you're using Ruby 1.9.x.

          set :ruby_url, "http://some-other-location.com/rubies/ruby.tar.gz"

        == The directory to which it expands

        If the tar to be downloaded does not extract a directory named after :ruby_version, \
        you need to set :ruby_dir.

          set :ruby_dir, "ruby-src-snapshot"

        == Patches

        Two performance patches will be applied by default. One is the optimized require patch, \
        the other one is an implementation of REE's GC tuning. \
        Both of these patches have been applied to 1.9.3. \
        If your Ruby is 1.9.2, but you don't want the patches, set it to false.

          set :apply_ruby_patches, false

        If the Ruby version is not 1.9.2, the patches won't applied anyway. \
        See more on GC tuning here:
        http://www.rubyenterpriseedition.com/documentation.html#_garbage_collector_performance_tuning
      DESC
      task :ruby, :except => { :no_release => true } do
        ruby_version = fetch :ruby_version, "ruby-1.9.2-p290"
        ruby_url     = fetch :ruby_url, "http://ftp.ruby-lang.org/pub/ruby/1.9/#{ruby_version}.tar.gz"
        ruby_dir     = fetch :ruby_dir, ruby_version
        tar_name     = File.basename(ruby_url)
        on_rollback { run "rm /tmp/#{tar_name}" }
        script = <<-BASH
          set -e
          cd /tmp

          log=/tmp/install-ruby-`date +%s`.log
          echo "=== Note: output is saved to $log"
          touch $log

          if [[ ! -f #{tar_name} ]]; then
            echo "=== Downloading #{ruby_version} from #{ruby_url}"
            curl -s -o #{tar_name} #{ruby_url}
          else
            echo "=== $(pwd)/#{tar_name} already present, using that one instead of downloading a new one"
          fi

          rm -rf #{ruby_dir}
          tar -zxf #{tar_name}
          cd #{ruby_dir}
        BASH

        if ruby_version =~ /^ruby-1.9.2/ && fetch(:apply_ruby_patches, true)
          script << <<-BASH
            echo "=== Applying Ruby patches"
            curl -s -o ree_gc_tuning.diff  https://raw.github.com/michaeledgar/ruby-patches/master/1.9/ree_gc_tuning/ree_gc_tuning.diff
            curl -s -o by_xavier_shay.diff https://raw.github.com/michaeledgar/ruby-patches/master/1.9/optimized_require/by_xavier_shay.diff
            patch -p 1 < ree_gc_tuning.diff >> $log
            patch -p 1 < by_xavier_shay.diff >> $log
          BASH
        end

        script << <<-BASH
          echo "=== Configuring #{ruby_version}"
          ./configure --disable-install-doc >> $log

          echo "=== Compiling #{ruby_version}"
          make >> $log 2>&1

          echo "=== Installing #{ruby_version}"
          #{sudo} make install >> $log
        BASH
        put script, "/tmp/install-ruby.sh", :via => :scp
        run "bash /tmp/install-ruby.sh"
      end

      desc "Install the gems needed for chef-solo"
      task :chef, :except => { :no_release => true } do
        chef_version = fetch :chef_version, ">= 0"
        run "#{sudo} #{sudo_opts} gem install chef --version '#{chef_version}' --no-ri --no-rdoc"
        run "#{sudo} #{sudo_opts} gem install ruby-shadow --no-ri --no-rdoc"
      end

    end

    def solo(*run_list)
      if run_list.empty?
        abort "Please specify a run list, before('deploy') { chef.solo('recipe[foo]', 'recipe[bar]') }"
      end
      ensure_cookbooks
      default
      run "mkdir -p /tmp/chef/cache"
      generate_config
      generate_attributes(run_list)
      copy_cookbooks
      stream_or_run "#{sudo} #{sudo_opts} chef-solo -c /tmp/chef/solo.rb -j /tmp/chef/solo.json"
    end

    def sudo_opts
      case os
      when "centos"
        "env PATH=$PATH" # to fix missing paths when using sudo
      end
    end

    def os
      fetch(:os, "ubuntu")
    end

    def ensure_cookbooks
      if cookbooks.empty?
        abort "Please put some cookbooks in `config/cookbooks` or `vendor/cookbooks` or set :cookbooks to a path where the cookbooks are located"
      end
    end

    def cookbooks
      Array(fetch(:cookbooks) { [ "config/cookbooks", "vendor/cookbooks" ].select { |path| File.exist?(path) } })
    end

    def generate_config
      cookbook_paths = cookbooks.map { |c| "File.join(root, #{c.to_s.inspect})" }.join(', ')
      solo_rb = <<-RUBY
        root = File.absolute_path(File.dirname(__FILE__))
        file_cache_path File.join(root, "cache")
        cookbook_path [ #{cookbook_paths} ]
      RUBY
      put solo_rb, "/tmp/chef/solo.rb", :via => :scp
    end

    def generate_attributes(run_list = [])
      attrs = fetch(:chef_attributes, {})
      if fetch(:default_chef_attributes, true)
        attrs[:application]  ||= fetch(:application, nil)
        attrs[:deploy_to]    ||= fetch(:deploy_to,   nil)
        attrs[:user]         ||= fetch(:user,        nil)
        attrs[:password]     ||= fetch(:password,    nil)
        attrs[:main_server]  ||= fetch(:main_server, nil)
        attrs[:migrate_env]  ||= fetch(:migrate_env, nil)
        attrs[:scm]          ||= fetch(:scm,         nil)
        attrs[:repository]   ||= fetch(:repository,  nil)
        attrs[:current_path] ||= current_path
        attrs[:release_path] ||= release_path
        attrs[:shared_path]  ||= shared_path
      end
      attrs[:run_list] = run_list
      put attrs.to_json, "/tmp/chef/solo.json", :via => :scp
    end

    def copy_cookbooks
      tar_file = Tempfile.new("cookbooks.tar")
      begin
        tar_file.close
        env_vars = fetch(:copyfile_disable, false) && RUBY_PLATFORM.downcase.include?('darwin') ? "COPYFILE_DISABLE=true" : ""
        system "#{env_vars} tar -cjf #{tar_file.path} #{cookbooks.join(' ')}"
        upload tar_file.path, "/tmp/chef/cookbooks.tar", :via => :scp
        run "cd /tmp/chef && tar -xjf cookbooks.tar"
      ensure
        tar_file.unlink
      end
    end

    def stream_or_run(*args)
      if fetch(:chef_streaming, true)
        stream *args
      else
        run *args
      end
    end

    def installed?(cmd)
      capture("which #{cmd}")
    rescue Capistrano::CommandError
      logger.info "#{cmd} has not been installed"
      false
    else
      logger.info "#{cmd} has been installed"
      true
    end

  end

end

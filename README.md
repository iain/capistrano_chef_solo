# Capistrano Chef-solo

This is an attempt to combine the powers of [Capistrano](http://capify.org) and
[chef-solo](http://wiki.opscode.com/display/chef/Chef+Solo).

You can easily specify run lists:

    before "deploy" do
      chef.solo "recipe[foo]", "recipe[bar]"
    end

And set some node attributes:

    set :chef_attributes, :foo => { :bar => "baz" }

Cookbooks will be automatically be copied from `config/cookbooks` and `vendor/cookbooks`.

Then an empty VM can be installed, configured and deployed in one single command:

    cap deploy

## Installation

Add to your `Gemfile`:

    gem 'capistrano_chef_solo', :require => false, :group => :development

And run `bundle install`.

Next, require me from your `Capfile`:

    require 'capistrano_chef_solo'

## Usage

Read the full documentation by typing:

    cap --explain chef | less

## Note

This gem is in very early stage of development and should be considered as just a spike at this
moment. Feel free to use it, and give me feedback on your experiences. But please, try it out on
a simple VM first.

## Todo

* Support roles in both Capistrano and Chef.

## Tips

### Colors

Capistrano and chef both give a lot of output. It helps to install
[capistrano_colors](https://github.com/stjernstrom/capistrano_colors)

### Vagrant

Using [Vagrant](http://vagrantup.com) is a good way for testing out chef recipes.

---
Copyright Iain Hecker, 2011. Released under the MIT License.

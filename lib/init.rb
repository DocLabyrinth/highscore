require 'global'
require 'bundler/setup'
require 'redis'
require 'mongoid'

Global.configure do |c|
  c.environment = ENV['RACK_ENV'] || 'development'
  c.config_directory = File.join( File.dirname(__FILE__), '..', 'config' )end

mongoid_yml = File.join( File.dirname(__FILE__), '..', 'config', 'mongoid.yml' )
Mongoid.load!(mongoid_yml, Global.environment.to_sym)

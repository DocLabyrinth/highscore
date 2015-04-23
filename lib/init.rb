require 'bundler/setup'
require 'global'
require 'redis'
require 'mongoid'

Global.configure do |c|
  c.environment = ENV['RACK_ENV'] || 'development'
  c.config_directory = File.join( File.dirname(__FILE__), '..', 'config' )end

mongoid_yml = File.join( File.dirname(__FILE__), '..', 'config', 'mongoid.yml' )
Mongoid.load!(mongoid_yml, Global.environment.to_sym)

lib_path = File.expand_path(File.dirname(__FILE__))
Dir["#{lib_path}/**/*.rb"].each{|f| require f}

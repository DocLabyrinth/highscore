ENV['RACK_ENV'] = 'test'

require 'mongoid-rspec'
require 'rr'
require 'init'

RSpec.configure do |config|
  config.include Mongoid::Matchers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rr

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

   config.before :each do
     Mongoid.purge!
     HighScore::Wrapper.redis.flushdb
   end
end

# add lib/ to the load path
$:.unshift File.join( File.dirname(__FILE__), '..', 'lib' )

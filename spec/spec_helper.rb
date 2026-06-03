# frozen_string_literal: true

if ENV['SILENCE_OUTPUT'] == 'true'
  $stdout = File.open(File::NULL, 'w')
  $stderr = File.open(File::NULL, 'w')
end

require 'bundler/setup'
require 'mysql2'
require 'timeout'
require 'ruby_mysql_tui'

RSpec.configure do |config|
  config.color = true
  # config.formatter = :documentation

  config.around(:each) do |example|
    Timeout.timeout(5) { example.run }
  end
end

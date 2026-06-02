# frozen_string_literal: true

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

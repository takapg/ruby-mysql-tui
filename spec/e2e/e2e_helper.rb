# frozen_string_literal: true

require 'mysql2'

module E2EHelper
  TEST_DB = 'tui_test_db'

  def self.setup_test_db
    with_mysql_retry('setup') do |client|
      client.query("DROP DATABASE IF EXISTS #{TEST_DB}")
      client.query("CREATE DATABASE #{TEST_DB}")
      client.query("USE #{TEST_DB}")
      setup_schema(client)
    end
  end

  def self.cleanup_test_db
    with_mysql_retry('cleanup') do |client|
      client.query("DROP DATABASE IF EXISTS #{TEST_DB}")
    end
  end

  def self.with_mysql_retry(context)
    5.times do |i|
      begin
        client = create_client
        return yield client
      rescue Mysql2::Error => e
        handle_mysql_retry(e, i + 1, context)
      ensure
        client&.close
      end
    end
  end

  def self.handle_mysql_retry(error, attempts, context)
    raise error if attempts >= 5

    warn "MySQL connection failed during #{context} (attempt #{attempts}/5): #{error.message}. Retrying in 1s..."
    sleep 1
  end
  private_class_method :with_mysql_retry, :handle_mysql_retry

  def self.create_client
    Mysql2::Client.new(
      host: ENV.fetch('MYSQL_HOST', '127.0.0.1'),
      username: ENV.fetch('MYSQL_USER', 'root'),
      password: ENV.fetch('MYSQL_PASSWORD', '')
    )
  end

  def self.setup_schema(client)
    client.query('CREATE TABLE test_table (id INT PRIMARY KEY, name VARCHAR(255))')
    client.query("INSERT INTO test_table (id, name) VALUES (1, 'Alice'), (2, 'Bob')")
  end

  private_class_method :create_client, :setup_schema
end

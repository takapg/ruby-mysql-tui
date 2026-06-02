# frozen_string_literal: true

require 'mysql2'

module E2EHelper
  TEST_DB = 'tui_test_db'

  def self.setup_test_db
    client = create_client
    client.query("DROP DATABASE IF EXISTS #{TEST_DB}")
    client.query("CREATE DATABASE #{TEST_DB}")
    client.query("USE #{TEST_DB}")
    setup_schema(client)
    client.close
  end

  def self.cleanup_test_db
    client = create_client
    client.query("DROP DATABASE IF EXISTS #{TEST_DB}")
    client.close
  end

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

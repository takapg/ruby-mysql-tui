require 'mysql2'

module E2EHelper
  TEST_DB = 'tui_test_db'

  def self.setup_test_db
    client = Mysql2::Client.new(
      host: ENV.fetch('MYSQL_HOST', '127.0.0.1'),
      username: ENV.fetch('MYSQL_USER', 'root'),
      password: ENV.fetch('MYSQL_PASSWORD', '')
    )
    client.query("DROP DATABASE IF EXISTS #{TEST_DB}")
    client.query("CREATE DATABASE #{TEST_DB}")
    client.query("USE #{TEST_DB}")
    client.query("CREATE TABLE test_table (id INT PRIMARY KEY, name VARCHAR(255))")
    client.query("INSERT INTO test_table (id, name) VALUES (1, 'Alice'), (2, 'Bob')")
    client.close
  end

  def self.cleanup_test_db
    client = Mysql2::Client.new(
      host: ENV.fetch('MYSQL_HOST', '127.0.0.1'),
      username: ENV.fetch('MYSQL_USER', 'root'),
      password: ENV.fetch('MYSQL_PASSWORD', '')
    )
    client.query("DROP DATABASE IF EXISTS #{TEST_DB}")
    client.close
  end
end

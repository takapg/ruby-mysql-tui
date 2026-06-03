# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/client'

RSpec.shared_context 'mysql client' do
  let(:config) { { host: 'localhost', username: 'root', password: '', database: 'test_db' } }
  let(:mock_mysql_client) { instance_double(Mysql2::Client) }

  before do
    allow(Mysql2::Client).to receive(:new).and_return(mock_mysql_client)
  end
end

RSpec.describe RubyMysqlTui::Client, '#initialize connection' do
  include_context 'mysql client'

  it 'connects to MySQL successfully' do
    expect { described_class.new(config) }.not_to raise_error
  end

  it 'raises Mysql2::Error when connection fails' do
    allow(Mysql2::Client).to receive(:new).and_raise(Mysql2::Error, 'Connection failed')
    expect { described_class.new(config) }.to raise_error(Mysql2::Error, 'Connection failed')
  end
end

RSpec.describe RubyMysqlTui::Client, '#initialize configuration' do
  include_context 'mysql client'

  it 'uses environment variables for configuration' do
    allow(ENV).to receive(:fetch).with('MYSQL_HOST', 'localhost').and_return('env-host')
    allow(ENV).to receive(:fetch).with('MYSQL_USER', 'root').and_return('env-user')
    allow(ENV).to receive(:fetch).with('MYSQL_PASSWORD', '').and_return('env-pass')
    allow(ENV).to receive(:fetch).with('MYSQL_DATABASE', nil).and_return('env-db')

    described_class.new
    expect(Mysql2::Client).to have_received(:new).with(
      hash_including(host: 'env-host', username: 'env-user', password: 'env-pass', database: 'env-db')
    )
  end

  it 'uses default values when no config or env vars are provided' do
    allow(ENV).to receive(:fetch).with('MYSQL_HOST', 'localhost').and_return('localhost')
    allow(ENV).to receive(:fetch).with('MYSQL_USER', 'root').and_return('root')
    allow(ENV).to receive(:fetch).with('MYSQL_PASSWORD', '').and_return('')
    allow(ENV).to receive(:fetch).with('MYSQL_DATABASE', nil).and_return(nil)

    described_class.new
    expect(Mysql2::Client).to have_received(:new).with(
      hash_including(host: 'localhost', username: 'root', password: '', database: nil)
    )
  end
end

RSpec.describe RubyMysqlTui::Client, '#list_databases' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }

  it 'executes SHOW DATABASES and returns a list of database names' do
    expect(mock_mysql_client).to receive(:query).with('SHOW DATABASES').and_return(
      [{ 'Database' => 'db1' }, { 'Database' => 'db2' }]
    )
    expect(client.list_databases).to eq(%w[db1 db2])
  end
end

RSpec.describe RubyMysqlTui::Client, '#list_columns' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:table_name) { 'users' }

  it 'executes SHOW COLUMNS and returns a list of column names' do
    expect(mock_mysql_client).to receive(:query).with("SHOW COLUMNS FROM `#{table_name}`").and_return(
      [{ 'Field' => 'id' }, { 'Field' => 'name' }]
    )
    expect(client.list_columns(table_name)).to eq(%w[id name])
  end
end

RSpec.describe RubyMysqlTui::Client, '#list_tables' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:db_name) { 'test_db' }

  it 'executes SHOW TABLES FROM `db_name` and returns a list of table names' do
    expect(mock_mysql_client).to receive(:query).with("SHOW TABLES FROM `#{db_name}`").and_return(
      [{ 'Tables_in_test_db' => 'table1' }, { 'Tables_in_test_db' => 'table2' }]
    )
    expect(client.list_tables(db_name)).to eq(%w[table1 table2])
  end

  it 'escapes backticks in database name' do
    db_name_with_backtick = 'my`db'
    expect(mock_mysql_client).to receive(:query).with('SHOW TABLES FROM `my``db`').and_return([])
    client.list_tables(db_name_with_backtick)
  end
end

RSpec.describe RubyMysqlTui::Client, '#list_records' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:table_name) { 'users' }

  it 'executes SELECT * FROM `table_name` with LIMIT and returns records' do
    records = [{ 'id' => 1, 'name' => 'Alice' }, { 'id' => 2, 'name' => 'Bob' }]
    sql = "SELECT * FROM `#{table_name}` LIMIT 100 OFFSET 0"
    expect(mock_mysql_client).to receive(:query).with(sql).and_return(records)
    expect(client.list_records(table_name)).to eq(records)
  end

  it 'executes SELECT * FROM `table_name` with LIMIT and OFFSET when offset is provided' do
    records = [{ 'id' => 101, 'name' => 'Charlie' }]
    sql = "SELECT * FROM `#{table_name}` LIMIT 100 OFFSET 100"
    expect(mock_mysql_client).to receive(:query).with(sql).and_return(records)
    expect(client.list_records(table_name, 100)).to eq(records)
  end
end

RSpec.describe RubyMysqlTui::Client, '#list_records (options)' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:table_name) { 'users' }

  it 'escapes backticks in table name' do
    table_name_with_backtick = 'user`s'
    records = []
    expect(mock_mysql_client).to receive(:query).with('SELECT * FROM `user``s` LIMIT 100 OFFSET 0').and_return(records)
    expect(client.list_records(table_name_with_backtick)).to eq(records)
  end

  it 'executes SELECT * FROM `table_name` without LIMIT when limit is nil' do
    records = [{ 'id' => 1, 'name' => 'Alice' }]
    sql = "SELECT * FROM `#{table_name}`"
    expect(mock_mysql_client).to receive(:query).with(sql).and_return(records)
    expect(client.list_records(table_name, 0, limit: nil)).to eq(records)
  end
end

RSpec.describe RubyMysqlTui::Client, '#query' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:sql) { 'SELECT 1' }

  it 'executes the query and returns results' do
    expect(mock_mysql_client).to receive(:query).with(sql).and_return([{ '1' => 1 }])
    expect(client.query(sql)).to eq([{ '1' => 1 }])
  end

  it 'logs the executed SQL' do
    allow(RubyMysqlTui.logger).to receive(:info)
    allow(mock_mysql_client).to receive(:query).and_return([])
    client.query(sql)
    expect(RubyMysqlTui.logger).to have_received(:info).with("Executing SQL: #{sql}")
  end

  it 'stores the last executed SQL' do
    allow(mock_mysql_client).to receive(:query).and_return([])
    client.query(sql)
    expect(client.last_sql).to eq(sql)
  end

  it 'handles Mysql2::Error and logs it' do
    allow(mock_mysql_client).to receive(:query).and_raise(Mysql2::Error, 'Query failed')
    expect(RubyMysqlTui.logger).to receive(:error).with(/MySQL Query Error: Query failed/)
    expect { client.query(sql) }.to raise_error(Mysql2::Error, 'Query failed')
  end
end

RSpec.describe RubyMysqlTui::Client, '#close' do
  include_context 'mysql client'

  it 'closes the connection' do
    client = described_class.new(config)
    expect(mock_mysql_client).to receive(:close)
    client.close
  end
end

RSpec.describe RubyMysqlTui::Client, '#list_table_structure' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:table_name) { 'users' }

  it 'executes SHOW COLUMNS and returns structure information' do
    structure = [{
      'Field' => 'id', 'Type' => 'int', 'Null' => 'NO', 'Key' => 'PRI', 'Default' => nil, 'Extra' => 'auto_increment'
    }]
    expect(mock_mysql_client).to receive(:query).with("SHOW COLUMNS FROM `#{table_name}`").and_return(structure)
    expect(client.list_table_structure(table_name)).to eq(structure)
  end
end

RSpec.describe RubyMysqlTui::Client, '#delete_record' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:table) { 'users' }
  let(:pk_col) { 'id' }
  let(:pk_val) { 1 }

  it 'uses a prepared statement to delete a record' do
    sql = "DELETE FROM `#{table}` WHERE `#{pk_col}` = ?"
    statement = instance_double('Mysql2::Statement')

    expect(mock_mysql_client).to receive(:prepare).with(sql).and_return(statement)
    expect(statement).to receive(:execute).with(pk_val)

    client.delete_record(table, pk_col, pk_val)
  end

  it 'escapes backticks in table and column names' do
    table_with_tick = 'user`s'
    col_with_tick = 'id`s'
    sql = 'DELETE FROM `user``s` WHERE `id``s` = ?'
    statement = instance_double('Mysql2::Statement')

    expect(mock_mysql_client).to receive(:prepare).with(sql).and_return(statement)
    expect(statement).to receive(:execute).with(pk_val)

    client.delete_record(table_with_tick, col_with_tick, pk_val)
  end
end

RSpec.describe RubyMysqlTui::Client, '#insert_record' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:table) { 'users' }
  let(:data) { { 'name' => 'New User', 'email' => 'user@example.com' } }

  it 'uses a prepared statement to insert a record' do
    sql = "INSERT INTO `#{table}` (`name`, `email`) VALUES (?, ?)"
    statement = instance_double('Mysql2::Statement')

    expect(mock_mysql_client).to receive(:prepare).with(sql).and_return(statement)
    expect(statement).to receive(:execute).with('New User', 'user@example.com')

    client.insert_record(table, data)
  end

  it 'escapes backticks in table and column names' do
    table_with_tick = 'user`s'
    data_with_tick = { 'name`s' => 'Value' }
    sql = 'INSERT INTO `user``s` (`name``s`) VALUES (?)'
    statement = instance_double('Mysql2::Statement')

    expect(mock_mysql_client).to receive(:prepare).with(sql).and_return(statement)
    expect(statement).to receive(:execute).with('Value')

    client.insert_record(table_with_tick, data_with_tick)
  end
end

RSpec.describe RubyMysqlTui::Client, '#select_database' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }

  it 'executes USE database_name and returns results' do
    db_name = 'test_db'
    expect(mock_mysql_client).to receive(:query).with("USE `#{db_name}`")
    client.select_database(db_name)
  end

  it 'escapes backticks in database name' do
    db_name_with_tick = 'my`db'
    expect(mock_mysql_client).to receive(:query).with('USE `my``db`')
    client.select_database(db_name_with_tick)
  end
end

RSpec.describe RubyMysqlTui::Client, '#create_database' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }

  it 'executes CREATE DATABASE and escapes backticks' do
    db_name = 'my`db'
    expect(mock_mysql_client).to receive(:query).with('CREATE DATABASE `my``db`')
    client.create_database(db_name)
  end
end

RSpec.describe RubyMysqlTui::Client, '#update_record' do
  include_context 'mysql client'
  let(:client) { described_class.new(config) }
  let(:table) { 'users' }
  let(:pk_col) { 'id' }
  let(:pk_val) { 1 }
  let(:edit_col) { 'name' }
  let(:new_val) { 'New Name' }

  it 'uses a prepared statement to update a record' do
    sql = "UPDATE `#{table}` SET `#{edit_col}` = ? WHERE `#{pk_col}` = ?"
    statement = instance_double('Mysql2::Statement')

    expect(mock_mysql_client).to receive(:prepare).with(sql).and_return(statement)
    expect(statement).to receive(:execute).with(new_val, pk_val)

    client.update_record(table, pk_col, pk_val, edit_col, new_val)
  end

  it 'escapes backticks in table and column names' do
    table_with_tick = 'user`s'
    col_with_tick = 'name`s'
    sql = "UPDATE `user``s` SET `name``s` = ? WHERE `#{pk_col}` = ?"
    statement = instance_double('Mysql2::Statement')

    expect(mock_mysql_client).to receive(:prepare).with(sql).and_return(statement)
    expect(statement).to receive(:execute).with(new_val, pk_val)

    client.update_record(table_with_tick, pk_col, pk_val, col_with_tick, new_val)
  end
end

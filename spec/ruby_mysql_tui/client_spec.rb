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
    expect(client.list_databases).to eq(['db1', 'db2'])
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

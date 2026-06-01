# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/client'

RSpec.describe RubyMysqlTui::Client do
  let(:config) { { host: 'localhost', username: 'root', password: '', database: 'test_db' } }
  let(:mock_mysql_client) { instance_double(Mysql2::Client) }

  before do
    allow(Mysql2::Client).to receive(:new).and_return(mock_mysql_client)
  end

  describe '#initialize' do
    it 'connects to MySQL successfully' do
      expect { described_class.new(config) }.not_to raise_error
    end

    it 'raises Mysql2::Error when connection fails' do
      allow(Mysql2::Client).to receive(:new).and_raise(Mysql2::Error, 'Connection failed')
      expect { described_class.new(config) }.to raise_error(Mysql2::Error, 'Connection failed')
    end
  end

  describe '#query' do
    let(:client) { described_class.new(config) }
    let(:sql) { 'SELECT 1' }

    it 'executes the query and returns results' do
      expect(mock_mysql_client).to receive(:query).with(sql).and_return([{ '1' => 1 }])
      expect(client.query(sql)).to eq([{ '1' => 1 }])
    end

    it 'logs the executed SQL' do
      expect(RubyMysqlTui.logger).to receive(:info).with("Executing SQL: #{sql}")
      allow(mock_mysql_client).to receive(:query).and_return([])
      client.query(sql)
    end

    it 'handles Mysql2::Error and logs it' do
      allow(mock_mysql_client).to receive(:query).and_raise(Mysql2::Error, 'Query failed')
      expect(RubyMysqlTui.logger).to receive(:error).with(/MySQL Query Error: Query failed/)
      expect { client.query(sql) }.to raise_error(Mysql2::Error, 'Query failed')
    end
  end
end

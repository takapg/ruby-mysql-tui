# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/pagination'

RSpec.describe RubyMysqlTui::InputHandler::Pagination, 'fetch_next_page success' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:state) { { selected_table: 'test_table', records_offset: 0, page_offset: 0, records: [] } }

  it 'handles Mysql2::Result by converting it to an array and does not raise NoMethodError' do
    mock_result = double('Mysql2::Result')
    allow(mock_result).to receive(:to_a).and_return([{ 'id' => 1 }])
    allow(mock_result).to receive(:empty?).and_raise(NoMethodError, "undefined method `empty?' for #<Mysql2::Result...>")

    allow(client).to receive(:list_records).and_return(mock_result)

    expect do
      described_class.fetch_next_page(state, client, page_offset: 0, size: 0)
    end.not_to raise_error

    expect(state[:records]).to eq([{ 'id' => 1 }])
    expect(state[:page_offset]).to eq(0)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::Pagination, 'fetch_next_page empty' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:state) { { selected_table: 'test_table', records_offset: 0, page_offset: 0, records: [] } }

  it 'handles empty Mysql2::Result correctly' do
    mock_result = double('Mysql2::Result')
    allow(mock_result).to receive(:to_a).and_return([])
    allow(mock_result).to receive(:empty?).and_raise(NoMethodError)

    allow(client).to receive(:list_records).and_return(mock_result)

    described_class.fetch_next_page(state, client, page_offset: 0, size: 10)
    expect(state[:records_offset]).to eq(9)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::Pagination, 'fetch_prev_page' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:state) do
    {
      selected_table: 'test_table',
      records_offset: 0,
      page_offset: 0,
      records: []
    }
  end

  describe '.fetch_prev_page' do
    it 'handles Mysql2::Result by converting it to an array' do
      state[:page_offset] = 100
      mock_result = double('Mysql2::Result')
      allow(mock_result).to receive(:to_a).and_return([{ 'id' => 1 }])
      allow(mock_result).to receive(:empty?).and_raise(NoMethodError)

      allow(client).to receive(:list_records).and_return(mock_result)

      expect do
        described_class.fetch_prev_page(state, client)
      end.not_to raise_error

      expect(state[:records]).to eq([{ 'id' => 1 }])
      expect(state[:page_offset]).to eq(100 - RubyMysqlTui::PAGE_SIZE)
    end
  end

  end
end

RSpec.describe RubyMysqlTui::InputHandler::Pagination, 'fetch_page_if_needed guard' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:layout) { instance_double('RubyMysqlTui::UI::Layout', main_h: 10) }
  let(:state) { { sql_result_mode: true, records_offset: 15, records: [], page_offset: 0 } }

  it 'does not fetch records when sql_result_mode is true' do
    expect(client).not_to receive(:list_records)
    described_class.fetch_page_if_needed(state, client, layout)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::Pagination, 'fetch_page_if_needed guard' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:layout) { instance_double('RubyMysqlTui::UI::Layout', main_h: 10) }
  let(:state) { { sql_result_mode: true, records_offset: 15, records: [], page_offset: 0 } }

  it 'does not fetch records when sql_result_mode is true' do
    expect(client).not_to receive(:list_records)
    described_class.fetch_page_if_needed(state, client, layout)
  end
end

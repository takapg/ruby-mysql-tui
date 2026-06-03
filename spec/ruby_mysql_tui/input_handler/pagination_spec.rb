# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/pagination'

RSpec.describe RubyMysqlTui::InputHandler::Pagination, 'fetch_next_page' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:state) do
    {
      selected_table: 'test_table',
      records_offset: 0,
      page_offset: 0,
      records: []
    }
  end

  describe '.fetch_next_page' do
    it 'handles Mysql2::Result by converting it to an array and does not raise NoMethodError' do
      # Mysql2::Result は to_a は持つが empty? は持たないため、それをシミュレートする
      mock_result = double('Mysql2::Result')
      allow(mock_result).to receive(:to_a).and_return([{ 'id' => 1 }])
      allow(mock_result).to receive(:empty?).and_raise(NoMethodError, "undefined method `empty?' for #<Mysql2::Result...>")

      allow(client).to receive(:list_records).and_return(mock_result)

      expect do
        described_class.fetch_next_page(state, client, 0, 0)
      end.not_to raise_error

      expect(state[:records]).to eq([{ 'id' => 1 }])
      expect(state[:page_offset]).to eq(0)
    end

    it 'handles empty Mysql2::Result correctly' do
      mock_result = double('Mysql2::Result')
      allow(mock_result).to receive(:to_a).and_return([])
      allow(mock_result).to receive(:empty?).and_raise(NoMethodError)

      allow(client).to receive(:list_records).and_return(mock_result)

      # page_offset=0, records_size=10 の場合、次ページが空なら offset を 9 に固定する
      described_class.fetch_next_page(state, client, 0, 10)
      expect(state[:records_offset]).to eq(9)
    end
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

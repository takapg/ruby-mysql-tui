# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/record_manager'

require_relative '../support/record_manager_setup'

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record guards' do
  include_context 'record manager setup'
  context 'when record management is not possible' do
    it 'returns state immediately if focus is :left' do
      state[:focus] = :left
      expect(client).not_to receive(:primary_key_for)
      expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
    end

    it 'returns state immediately if view_mode is not :records' do
      state[:view_mode] = :tables
      expect(client).not_to receive(:primary_key_for)
      expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
    end

    it 'returns state immediately if records are nil' do
      state[:records] = nil
      expect(client).not_to receive(:primary_key_for)
      expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
    end
  end

  it 'returns state if primary key is not found' do
    allow(client).to receive(:primary_key_for).and_return(nil)
    expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_create_record' do
  include_context 'record manager setup'

  it 'prompts for all columns and inserts a record' do
    allow(client).to receive(:list_columns).with('test_table').and_return(%w[id name])
    allow(prompt).to receive(:ask).with(/id/).and_return('1')
    allow(prompt).to receive(:ask).with(/name/).and_return('Alice')
    expect(client).to receive(:insert_record).with('test_table', { 'id' => '1', 'name' => 'Alice' })
    expect(client).to receive(:list_records)

    described_class.handle_create_record(state, client, prompt)
  end

  it 'handles MySQL error during insertion' do
    allow(client).to receive(:list_columns).and_return(%w[id])
    allow(prompt).to receive(:ask).and_return('1')
    allow(client).to receive(:insert_record).and_raise(Mysql2::Error, 'Insert failed')
    expect(prompt).to receive(:say).with(/挿入に失敗しました/, color: :red)

    described_class.handle_create_record(state, client, prompt)
  end
end

# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/ruby_mysql_tui/input_handler/table_manager'

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_create_table (success)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { items: %w[t1 t2], selected_index: 0, selected_db: 'test_db' } }

  it 'creates a table when a valid name is provided' do
    allow(prompt).to receive(:ask).and_return('new_table', '')
    expect(client).to receive(:create_table).with('new_table', [])
    expect(client).to receive(:list_tables).with('test_db').and_return(%w[t1 t2 new_table])

    result = described_class.handle_create_table(state, client, prompt)
    expect(result[:items]).to eq(%w[t1 t2 new_table])
  end

  it 'creates a table with custom columns when provided' do
    allow(prompt).to receive(:ask).and_return('new_table', 'name, email')
    expect(client).to receive(:create_table).with('new_table', %w[name email])
    expect(client).to receive(:list_tables).with('test_db').and_return(%w[t1 t2 new_table])

    result = described_class.handle_create_table(state, client, prompt)
    expect(result[:items]).to eq(%w[t1 t2 new_table])
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_create_table (edge cases)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { items: %w[t1 t2], selected_index: 0, selected_db: 'test_db' } }

  it 'returns state unchanged when name is empty' do
    allow(prompt).to receive(:ask).and_return('  ')
    result = described_class.handle_create_table(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'handles Mysql2::Error' do
    allow(prompt).to receive(:ask).and_return('new_table')
    allow(client).to receive(:create_table).and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_create_table(state, client, prompt)
    expect(result).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_drop_table' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { items: %w[t1 t2], selected_index: 0, selected_db: 'test_db' } }

  it 'drops a table when confirmed' do
    allow(prompt).to receive(:yes?).and_return(true)
    expect(client).to receive(:drop_table).with('t1')
    expect(client).to receive(:list_tables).with('test_db').and_return(%w[t2])

    result = described_class.handle_drop_table(state, client, prompt)
    expect(result[:items]).to eq(%w[t2])
    expect(result[:status_message]).to eq("Table 't1' deleted successfully")
  end

  it 'cancels deletion when not confirmed' do
    allow(prompt).to receive(:yes?).and_return(false)
    result = described_class.handle_drop_table(state, client, prompt)
    expect(result[:status_message]).to eq('Deletion cancelled')
  end

  it 'handles Mysql2::Error' do
    allow(prompt).to receive(:yes?).and_return(true)
    allow(client).to receive(:drop_table).and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_drop_table(state, client, prompt)
    expect(result).to eq(state)
  end
end

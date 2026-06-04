# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui'
require 'ruby_mysql_tui/input_handler/record_executor'

RSpec.describe RubyMysqlTui::InputHandler::RecordExecutor, '.execute_insert' do
  let(:state) { { selected_table: 'test_table', records_offset: 0 } }
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }

  it 'inserts a record and refreshes records' do
    data = { 'name' => 'Alice' }
    expect(client).to receive(:insert_record).with('test_table', data)
    expect(client).to receive(:list_records).with('test_table', 0).and_return([{ 'id' => 1, 'name' => 'Alice' }])

    described_class.execute_insert(state, client, prompt, data)
    expect(state[:records]).to eq([{ 'id' => 1, 'name' => 'Alice' }])
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordExecutor, '.confirm_and_delete (cancellation)' do
  let(:state) { { selected_table: 'test_table', records_offset: 0 } }
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:record) { { 'id' => 1, 'name' => 'Alice' } }
  let(:pk_column) { 'id' }

  it 'returns false and sets cancellation message when user says no' do
    allow(prompt).to receive(:yes?).and_return(false)

    result = described_class.confirm_and_delete(state, client, prompt, record, pk_column)

    expect(result).to be false
    expect(state[:status_message]).to eq('Deletion cancelled')
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordExecutor, '.confirm_and_delete (execution)' do
  let(:state) { { selected_table: 'test_table', records_offset: 0 } }
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:record) { { 'id' => 1, 'name' => 'Alice' } }
  let(:pk_column) { 'id' }

  it 'deletes record and sets success message when user says yes' do
    allow(prompt).to receive(:yes?).and_return(true)
    expect(client).to receive(:delete_record).with('test_table', 'id', 1)
    expect(client).to receive(:list_records).with('test_table', 0).and_return([])

    result = described_class.confirm_and_delete(state, client, prompt, record, pk_column)

    expect(result).to be true
    expect(state[:status_message]).to eq('Record deleted successfully')
  end

  it 'handles Mysql2::Error and sets error message' do
    allow(prompt).to receive(:yes?).and_return(true)
    allow(client).to receive(:delete_record).and_raise(Mysql2::Error.new('Delete failed'))

    result = described_class.confirm_and_delete(state, client, prompt, record, pk_column)

    expect(result).to be false
    expect(state[:status_message]).to include('Failed to delete record: Delete failed')
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordExecutor, '.execute_update' do
  let(:state) { { selected_table: 'test_table', records_offset: 0 } }
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }

  it 'updates record and refreshes records' do
    info = { pk_col: 'id', pk_val: 1, col: 'name', val: 'Bob' }
    expect(client).to receive(:update_record).with('test_table', 'id', 1, 'name', 'Bob')
    expect(client).to receive(:list_records).with('test_table', 0).and_return([{ 'id' => 1, 'name' => 'Bob' }])

    described_class.execute_update(state, client, prompt, info)
    expect(state[:records]).to eq([{ 'id' => 1, 'name' => 'Bob' }])
  end
end

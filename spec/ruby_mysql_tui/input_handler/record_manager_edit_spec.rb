# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/record_manager'

require_relative '../support/record_manager_setup'

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record success' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
  end

  it 'updates the record when valid column and value are provided' do
    expect(prompt).to receive(:select).with('編集するカラムを選択してください:', record.keys).and_return('name')
    expect(prompt).to receive(:ask).with(any_args).and_return('Bob')
    expect(client).to receive(:update_record).with(table_name, pk_column, 1, 'name', 'Bob')
    expect(client).to receive(:list_records).with(table_name, 0).and_return([{ 'id' => 1, 'name' => 'Bob' }])

    result_state = described_class.handle_edit_record(state, client, prompt)
    expect(result_state[:records]).to eq([{ 'id' => 1, 'name' => 'Bob' }])
  end

  it 'does not update when value is nil' do
    expect(prompt).to receive(:select).and_return('name')
    expect(prompt).to receive(:ask).and_return(nil)
    expect(client).not_to receive(:update_record)

    described_class.handle_edit_record(state, client, prompt)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record retry limit' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
  end

  it 'stops record editing after 5 failed retries' do
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('Bob')
    allow(prompt).to receive(:say)
    allow(RubyMysqlTui.logger).to receive(:error)

    expect(client).to receive(:update_record).exactly(5).times.and_raise(Mysql2::Error, 'Persistent failure')

    described_class.handle_edit_record(state, client, prompt)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record failure' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
    allow(client).to receive(:list_records).and_return(state[:records])
  end

  it 'handles Mysql2::Error during update' do
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('Bob', nil)
    allow(client).to receive(:update_record).and_raise(Mysql2::Error, 'Update failed')
    expect(RubyMysqlTui.logger).to receive(:error).with(/Failed to update record: Update failed/)
    expect(prompt).to receive(:say).with(/更新に失敗しました: Update failed/, color: :red)

    described_class.handle_edit_record(state, client, prompt)
  end

  it 'shows specific message for duplicate entry error' do
    allow(prompt).to receive(:select).and_return('id')
    allow(prompt).to receive(:ask).and_return('duplicate_id', 'unique_id', nil)
    allow(client).to receive(:update_record).and_invoke(
      ->(*_args) { raise Mysql2::Error, "Duplicate entry 'duplicate_id' for key 'PRIMARY'" },
      ->(*_args) { true }
    )
    expect(prompt).to receive(:say).with(/主キーまたはユニーク制約違反（重複）です/, color: :red)

    described_class.handle_edit_record(state, client, prompt)
  end
end

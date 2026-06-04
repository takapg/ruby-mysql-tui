# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/record_manager'

require_relative '../support/record_manager_setup'

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record success' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
    allow(client).to receive(:list_table_structure).with(table_name).and_return([])
  end

  it 'updates the record when valid column and value are provided' do
    expect(prompt).to receive(:select).with('編集するカラムを選択してください:', record.keys - [pk_column]).and_return('name')
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

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record PK validation' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
    allow(client).to receive(:list_table_structure).with(table_name).and_return([])
  end

  it 'shows a warning and does not update when the primary key is selected' do
    # RecordPrompt のフィルタリングをバイパスして PK が選択された状況をシミュレート
    expect(prompt).to receive(:select).and_return(pk_column)
    expect(prompt).to receive(:ask).and_return('new_pk_val')
    expect(prompt).to receive(:say).with('主キーは編集できません', color: :red)
    expect(client).not_to receive(:update_record)

    described_class.handle_edit_record(state, client, prompt)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record no primary key' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(nil)
    allow(client).to receive(:list_table_structure).with(table_name).and_return([])
  end

  it 'returns state and shows warning when no primary key is found' do
    expect(prompt).to receive(:say).with('このテーブルには主キーが設定されていないため、レコードを特定して更新することができず、編集は不可能です', color: :yellow)
    expect(prompt).not_to receive(:select)
    result_state = described_class.handle_edit_record(state, client, prompt)
    expect(result_state).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record no editable columns' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
    allow(client).to receive(:list_table_structure).with(table_name).and_return([])
    state[:records] = [{ pk_column => 1 }]
  end

  it 'shows a warning and does not update when only the primary key exists' do
    expect(prompt).to receive(:say).with('編集可能なカラムがありません', color: :yellow)
    expect(client).not_to receive(:update_record)

    described_class.handle_edit_record(state, client, prompt)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record retry limit' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
    allow(client).to receive(:list_table_structure).with(table_name).and_return([])
  end

  it 'stops record editing after 5 failed retries' do
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('Bob')
    allow(prompt).to receive(:say)
    allow(RubyMysqlTui.logger).to receive(:error)

    error = Mysql2::Error.new('Duplicate entry')
    allow(error).to receive(:errno).and_return(1062)
    expect(client).to receive(:update_record).exactly(5).times.and_raise(error)

    described_class.handle_edit_record(state, client, prompt)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record failure' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
    allow(client).to receive(:list_table_structure).with(table_name).and_return([])
  end

  it 'handles Mysql2::Error during update' do
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('Bob')
    allow(client).to receive(:update_record).and_raise(Mysql2::Error, 'Update failed')
    expect(RubyMysqlTui.logger).to receive(:error).with(/更新に失敗しました: Update failed/).once
    expect(prompt).to receive(:say).with(/更新に失敗しました: Update failed/, color: :red).once

    described_class.handle_edit_record(state, client, prompt)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record duplicate entry' do
  include_context 'record manager setup'
  before do
    allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
    allow(client).to receive(:list_table_structure).with(table_name).and_return([])
  end

  it 'handles duplicate entry error specifically' do
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('duplicate_id', nil)

    # errno 1062 を持つエラーをシミュレート
    error = Mysql2::Error.new('Duplicate entry')
    allow(error).to receive(:errno).and_return(1062)
    allow(client).to receive(:update_record).and_raise(error)

    expect(prompt).to receive(:say).with(/入力された値は既に存在するため、保存できません/, color: :red)

    described_class.handle_edit_record(state, client, prompt)
  end

  it 'stops record editing after 5 failed duplicate entry retries' do
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('duplicate_id')
    allow(prompt).to receive(:say)
    allow(RubyMysqlTui.logger).to receive(:error)

    error = Mysql2::Error.new('Duplicate entry')
    allow(error).to receive(:errno).and_return(1062)
    expect(client).to receive(:update_record).exactly(5).times.and_raise(error)

    described_class.handle_edit_record(state, client, prompt)
  end
end

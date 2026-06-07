# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
require 'ruby_mysql_tui/input_handler/record_manager'

require_relative '../support/record_manager_setup'

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_clone_record (success)' do
  include_context 'record manager setup'

  it 'prompts for record data with existing values as defaults (excluding PK)' do
    Timeout.timeout(10) do
      state[:selected_table] = 'users'
      state[:records] = [{ 'id' => '1', 'name' => 'Alice', 'email' => 'alice@example.com' }]
      state[:selected_record_index] = 0
      allow(client).to receive(:primary_key_for).with('users').and_return('id')
      allow(client).to receive(:list_columns).with('users').and_return(%w[id name email])
      allow(client).to receive(:list_table_structure).and_return([])

      # PK 'id' は除外され、name と email がデフォルト値として渡されることを検証
      expect(prompt).to receive(:ask).with(/id/, anything).and_return('2')
      expect(prompt).to receive(:ask).with(/name/, hash_including(default: 'Alice')).and_return('Bob')
      expect(prompt).to receive(:ask)
        .with(/email/, hash_including(default: 'alice@example.com'))
        .and_return('bob@example.com')

      expect(client).to receive(:insert_record).with(
        'users', { 'id' => '2', 'name' => 'Bob', 'email' => 'bob@example.com' }
      )
      allow(client).to receive(:list_records).and_return(state[:records])

      described_class.handle_clone_record(state, client, prompt)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_clone_record (cancel)' do
  include_context 'record manager setup'

  it 'returns state if user cancels input' do
    Timeout.timeout(10) do
      state[:selected_table] = 'users'
      state[:records] = [{ 'id' => '1', 'name' => 'Alice' }]
      state[:selected_record_index] = 0
      allow(client).to receive(:primary_key_for).and_return('id')
      allow(client).to receive(:list_columns).and_return(%w[id name])
      allow(client).to receive(:list_table_structure).and_return([])
      allow(prompt).to receive(:ask).and_return(nil)

      expect(client).not_to receive(:insert_record)
      expect(described_class.handle_clone_record(state, client, prompt)).to eq(state)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_clone_record (not selected)' do
  include_context 'record manager setup'

  it 'returns state immediately' do
    Timeout.timeout(10) do
      state[:records] = []
      expect(client).not_to receive(:primary_key_for)
      expect(described_class.handle_clone_record(state, client, prompt)).to eq(state)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record' do
  include_context 'record manager setup'

  it 'retries record editing when an error occurs' do
    Timeout.timeout(10) do
      state[:selected_table] = 'users'
      state[:records] = [{ 'id' => '1', 'name' => 'Alice' }]
      state[:selected_record_index] = 0
      allow(client).to receive(:primary_key_for).with('users').and_return('id')
      allow(client).to receive(:list_table_structure).and_return([])

      allow(prompt).to receive(:select).and_return('name')
      allow(prompt).to receive(:ask).and_return('invalid', 'valid')
      allow(prompt).to receive(:say)

      error = Mysql2::Error.new('Duplicate entry')
      allow(error).to receive(:errno).and_return(1062)

      expect(client).to receive(:update_record)
        .with('users', 'id', '1', 'name', 'invalid')
        .and_raise(error)
      expect(client).to receive(:update_record).with('users', 'id', '1', 'name', 'valid').and_return(true)
      allow(client).to receive(:list_records).and_return(state[:records])

      described_class.handle_edit_record(state, client, prompt)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.can_manage_record?' do
  include_context 'record manager setup'

  it 'returns true when focus is :right and view_mode is :records' do
    state[:focus] = :right
    state[:view_mode] = :records
    state[:records] = [{ 'id' => 1 }]
    expect(described_class.can_manage_record?(state)).to be true
  end

  it 'returns true when focus is :right and view_mode is :record_detail' do
    state[:focus] = :right
    state[:view_mode] = :record_detail
    state[:records] = [{ 'id' => 1 }]
    expect(described_class.can_manage_record?(state)).to be true
  end

  it 'returns false when focus is :left' do
    state[:focus] = :left
    state[:view_mode] = :records
    state[:records] = [{ 'id' => 1 }]
    expect(described_class.can_manage_record?(state)).to be false
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_delete_record transition' do
  include_context 'record manager setup'

  it 'transitions from :record_detail to :records after successful deletion' do
    state[:focus] = :right
    state[:view_mode] = :record_detail
    state[:records] = [{ 'id' => 1 }]
    state[:selected_record_index] = 0
    allow(client).to receive(:primary_key_for).and_return('id')
    allow(prompt).to receive(:yes?).and_return(true)
    allow(client).to receive(:delete_record).and_return(true)
    allow(client).to receive(:list_records).and_return([])

    result = described_class.handle_delete_record(state, client, prompt)
    expect(result[:view_mode]).to eq(:records)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record guards' do
  include_context 'record manager setup'

  context 'when record management is not possible' do
    it 'returns state immediately if focus is :left' do
      Timeout.timeout(10) do
        state[:focus] = :left
        expect(client).not_to receive(:primary_key_for)
        expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
      end
    end

    it 'returns state immediately if view_mode is not :records' do
      Timeout.timeout(10) do
        state[:view_mode] = :tables
        expect(client).not_to receive(:primary_key_for)
        expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
      end
    end

    it 'returns state immediately if records are nil' do
      Timeout.timeout(10) do
        state[:records] = nil
        expect(client).not_to receive(:primary_key_for)
        expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
      end
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record primary key guard' do
  include_context 'record manager setup'

  it 'returns state and shows warning if primary key is not found' do
    Timeout.timeout(10) do
      allow(client).to receive(:primary_key_for).and_return(nil)
      expect(prompt).to receive(:say).with('このテーブルには主キーが設定されていないため、レコードを特定して更新することができず、編集は不可能です', color: :yellow)
      expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_create_record' do
  include_context 'record manager setup'

  it 'prompts for all columns and inserts a record' do
    Timeout.timeout(10) do
      allow(client).to receive(:list_columns).with('users').and_return(%w[id name])
      allow(client).to receive(:list_table_structure).and_return([])
      allow(prompt).to receive(:ask).with(/id/, anything).and_return('1')
      allow(prompt).to receive(:ask).with(/name/, anything).and_return('Alice')
      expect(client).to receive(:insert_record).with('users', { 'id' => '1', 'name' => 'Alice' })
      expect(client).to receive(:list_records)

      described_class.handle_create_record(state, client, prompt)
    end
  end

  it 'stops record creation after 5 failed retries' do
    Timeout.timeout(10) do
      allow(client).to receive(:list_columns).and_return(%w[id])
      allow(client).to receive(:list_table_structure).and_return([])
      allow(prompt).to receive(:ask).and_return('val')
      allow(prompt).to receive(:say)

      error = Mysql2::Error.new('Persistent failure')
      allow(error).to receive(:errno).and_return(1062)
      expect(client).to receive(:insert_record).exactly(5).times.and_raise(error)

      described_class.handle_create_record(state, client, prompt)
    end
  end
end

RSpec.shared_context 'external edit setup' do
  include_context 'record manager setup'

  let(:table_name) { 'users' }
  let(:structure) do
    [
      { 'Field' => 'id', 'Type' => 'int(11)', 'Null' => 'NO', 'Key' => 'PRI' },
      { 'Field' => 'content', 'Type' => 'text', 'Null' => 'YES', 'Key' => '' },
      { 'Field' => 'name', 'Type' => 'varchar(255)', 'Null' => 'YES', 'Key' => '' }
    ]
  end

  before do
    state[:focus] = :right
    state[:view_mode] = :record_detail
    state[:selected_table] = table_name
    state[:records] = [{ 'id' => 1, 'content' => 'old content', 'name' => 'Alice' }]
    state[:selected_record_index] = 0
    allow(client).to receive(:primary_key_for).with(table_name).and_return('id')
    allow(client).to receive(:list_table_structure).with(table_name).and_return(structure)
    allow(client).to receive(:list_records).and_return(state[:records])
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_external_edit (success)' do
  include_context 'external edit setup'

  it 'updates the record when edited via external editor' do
    state[:selected_column_index] = 1 # 'content' (text)
    allow(RubyMysqlTui::InputHandler::SqlEditor).to receive(:edit_in_editor).and_return('new content')
    expect(client).to receive(:update_record).with(table_name, 'id', 1, 'content', 'new content')
    described_class.handle_external_edit(state, client, prompt)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_external_edit (guards)' do
  include_context 'external edit setup'

  context 'when editing a non-long-text column' do
    it 'does not open editor' do
      state[:selected_column_index] = 2 # 'name' (varchar)
      expect(RubyMysqlTui::InputHandler::SqlEditor).not_to receive(:edit_in_editor)
      described_class.handle_external_edit(state, client, prompt)
    end
  end

  context 'when editing a primary key column' do
    it 'shows warning and does not open editor' do
      state[:selected_column_index] = 0 # 'id' (PK)
      expect(prompt).to receive(:say).with(/主キーは編集できません/, color: :red)
      expect(RubyMysqlTui::InputHandler::SqlEditor).not_to receive(:edit_in_editor)
      described_class.handle_external_edit(state, client, prompt)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.perform_update' do
  include_context 'record manager setup'

  it 'prevents updating the primary key and shows a warning' do
    info = { pk_col: 'id', pk_val: '1', pk_cols: ['id'], col: 'id', val: '2' }
    expect(prompt).to receive(:say).with('主キーは編集できません', color: :red)
    expect(RubyMysqlTui::InputHandler::RecordRetryHandler).not_to receive(:execute_update_with_retry)

    described_class.perform_update(state, client, prompt, info)
  end

  it 'prevents updating any column that is part of a composite primary key' do
    info = { pk_col: 'id1', pk_val: '1', pk_cols: %w[id1 id2], col: 'id2', val: '2' }
    expect(prompt).to receive(:say).with('主キーは編集できません', color: :red)
    expect(RubyMysqlTui::InputHandler::RecordRetryHandler).not_to receive(:execute_update_with_retry)

    described_class.perform_update(state, client, prompt, info)
  end

  it 'calls RecordRetryHandler when the column is not the primary key' do
    info = { pk_col: 'id', pk_val: '1', pk_cols: ['id'], col: 'name', val: 'Bob' }
    expect(RubyMysqlTui::InputHandler::RecordRetryHandler)
      .to receive(:execute_update_with_retry).with(state, client, prompt, info)

    described_class.perform_update(state, client, prompt, info)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_create_record error handling' do
  include_context 'record manager setup'

  it 'handles MySQL error during insertion' do
    Timeout.timeout(10) do
      allow(client).to receive(:list_columns).and_return(%w[id])
      allow(client).to receive(:list_table_structure).and_return([])
      allow(prompt).to receive(:ask).and_return('1', nil)
      allow(client).to receive(:insert_record).and_raise(Mysql2::Error, 'Insert failed')
      expect(prompt).to receive(:say).with(/挿入に失敗しました/, color: :red)

      described_class.handle_create_record(state, client, prompt)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_create_record retry handling' do
  include_context 'record manager setup'

  it 'retries record creation when an error occurs' do
    Timeout.timeout(10) do
      allow(client).to receive(:list_columns).and_return(%w[id])
      allow(client).to receive(:list_table_structure).and_return([])
      allow(prompt).to receive(:ask).and_return('invalid', 'valid')
      allow(prompt).to receive(:say)

      error = Mysql2::Error.new('Invalid value')
      allow(error).to receive(:errno).and_return(1062)
      expect(client).to receive(:insert_record)
        .with('users', { 'id' => 'invalid' })
        .and_raise(error)
      expect(client).to receive(:insert_record).with('users', { 'id' => 'valid' }).and_return(true)
      allow(client).to receive(:list_records).and_return([])

      described_class.handle_create_record(state, client, prompt)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_create_record retry handling - decline' do
  include_context 'record manager setup'

  it 'stops record creation when user declines retry after error' do
    Timeout.timeout(10) do
      allow(client).to receive(:list_columns).and_return(%w[id])
      allow(client).to receive(:list_table_structure).and_return([])
      allow(prompt).to receive(:ask).and_return('invalid', nil)
      allow(client).to receive(:insert_record).and_raise(Mysql2::Error, 'Insert failed')
      expect(prompt).to receive(:say).with(/挿入に失敗しました/, color: :red)

      described_class.handle_create_record(state, client, prompt)
    end
  end
end

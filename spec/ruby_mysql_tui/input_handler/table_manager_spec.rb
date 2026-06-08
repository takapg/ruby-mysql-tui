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
    allow(prompt).to receive(:ask).and_return('new_table', 'name', 'email')
    allow(prompt).to receive(:select).and_return('VARCHAR(255)', 'VARCHAR(255)')
    # yes? sequence: name_null=true, name_more=true, email_null=false, email_more=false
    allow(prompt).to receive(:yes?).and_return(true, true, false, false)
    expect(client).to receive(:create_table).with(
      'new_table',
      [
        { name: 'name', type: 'VARCHAR(255) NULL' },
        { name: 'email', type: 'VARCHAR(255) NOT NULL' }
      ]
    )
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
    allow(prompt).to receive(:ask).and_return('new_table', 'col1')
    allow(prompt).to receive(:select).and_return('INT')
    allow(prompt).to receive(:yes?).and_return(false)
    allow(client).to receive(:create_table).and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_create_table(state, client, prompt)
    expect(result).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_rename_table' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { items: %w[t1 t2], selected_index: 0, selected_db: 'test_db' } }

  it 'renames a table when a valid new name is provided' do
    allow(prompt).to receive(:ask).and_return('new_t1')
    expect(client).to receive(:rename_table).with('t1', 'new_t1')
    expect(client).to receive(:list_tables).with('test_db').and_return(%w[new_t1 t2])

    result = described_class.handle_rename_table(state, client, prompt)
    expect(result[:items]).to eq(%w[new_t1 t2])
    expect(result[:status_message]).to eq("Table 't1' renamed to 'new_t1' successfully")
  end

  it 'returns state unchanged when new name is empty' do
    allow(prompt).to receive(:ask).and_return('  ')
    result = described_class.handle_rename_table(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'handles Mysql2::Error' do
    allow(prompt).to receive(:ask).and_return('new_t1')
    allow(client).to receive(:rename_table).and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_rename_table(state, client, prompt)
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

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_truncate_table' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { items: %w[t1 t2], selected_index: 0, selected_db: 'test_db' } }

  it 'truncates a table when confirmed' do
    allow(prompt).to receive(:yes?).and_return(true)
    expect(client).to receive(:truncate_table).with('t1')

    result = described_class.handle_truncate_table(state, client, prompt)
    expect(result[:status_message]).to eq("Table 't1' truncated successfully")
  end

  it 'cancels truncation when not confirmed' do
    allow(prompt).to receive(:yes?).and_return(false)
    result = described_class.handle_truncate_table(state, client, prompt)
    expect(result[:status_message]).to eq('Truncation cancelled')
  end

  it 'handles Mysql2::Error' do
    allow(prompt).to receive(:yes?).and_return(true)
    allow(client).to receive(:truncate_table).and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_truncate_table(state, client, prompt)
    expect(result).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_drop_column (success/cancel)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { selected_table: 'test_table', records: [{ 'Field' => 'col1', 'Key' => '' }] } }

  it 'drops a column when confirmed' do
    allow(prompt).to receive(:yes?).and_return(true)
    expect(RubyMysqlTui::InputHandler::TableExecutor)
      .to receive(:execute_drop_column).with(state, client, 'test_table', 'col1').and_return(state)

    result = described_class.handle_drop_column(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'cancels deletion when not confirmed' do
    allow(prompt).to receive(:yes?).and_return(false)
    result = described_class.handle_drop_column(state, client, prompt)
    expect(result[:status_message]).to eq('Deletion cancelled')
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_drop_column (errors)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { selected_table: 'test_table', records: [{ 'Field' => 'col1', 'Key' => '' }] } }

  it 'refuses to drop primary key' do
    state[:records] = [{ 'Field' => 'id', 'Key' => 'PRI' }]
    expect(prompt).to receive(:error).with(/主キーカラム 'id' は削除できません/)
    result = described_class.handle_drop_column(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'handles Mysql2::Error' do
    allow(prompt).to receive(:yes?).and_return(true)
    allow(client).to receive(:drop_column).and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_drop_column(state, client, prompt)
    expect(result).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_add_column' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { selected_table: 'test_table', records: [] } }

  it 'adds a column and updates state' do
    allow(prompt).to receive(:ask).and_return('new_col')
    allow(prompt).to receive(:select).and_return('VARCHAR(255)')
    allow(prompt).to receive(:yes?).and_return(false)
    expect(client).to receive(:add_column).with('test_table', 'new_col', 'VARCHAR(255) NOT NULL')
    expect(client).to receive(:list_table_structure).with('test_table').and_return([{ 'Field' => 'new_col' }])

    result = described_class.handle_add_column(state, client, prompt)
    expect(result[:records]).to eq([{ 'Field' => 'new_col' }])
    expect(result[:status_message]).to eq("Column 'new_col' added to 'test_table' successfully")
  end

  it 'returns state unchanged when column name is empty' do
    allow(prompt).to receive(:ask).and_return('  ')
    result = described_class.handle_add_column(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'handles Mysql2::Error' do
    allow(prompt).to receive(:ask).and_return('new_col')
    allow(prompt).to receive(:select).and_return('INT')
    allow(prompt).to receive(:yes?).and_return(true)
    allow(client).to receive(:add_column).and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_add_column(state, client, prompt)
    expect(result).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_rename_column (success)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { selected_table: 'test_table', records: [{ 'Field' => 'old_col' }], selected_record_index: 0 } }

  it 'renames a column when a valid new name is provided' do
    allow(prompt).to receive(:ask).and_return('new_col')
    expect(RubyMysqlTui::InputHandler::TableExecutor).to receive(:execute_rename_column)
      .with(state, client, 'test_table', 'old_col', 'new_col')
      .and_return(state.merge(status_message: "Column 'old_col' renamed to 'new_col' successfully"))

    result = described_class.handle_rename_column(state, client, prompt)
    expect(result[:status_message]).to eq("Column 'old_col' renamed to 'new_col' successfully")
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_rename_column (edge cases)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { selected_table: 'test_table', records: [{ 'Field' => 'old_col' }], selected_record_index: 0 } }

  it 'returns state unchanged when new name is empty' do
    allow(prompt).to receive(:ask).and_return('  ')
    result = described_class.handle_rename_column(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'returns state unchanged when no column is selected' do
    state[:records] = []
    result = described_class.handle_rename_column(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'handles Mysql2::Error' do
    allow(prompt).to receive(:ask).and_return('new_col')
    allow(RubyMysqlTui::InputHandler::TableExecutor).to receive(:execute_rename_column)
      .and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_rename_column(state, client, prompt)
    expect(result).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::TableManager, '.handle_modify_column' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { selected_table: 'test_table', records: [{ 'Field' => 'age' }], selected_record_index: 0 } }

  it 'modifies column type when a type is selected' do
    allow(prompt).to receive(:select).and_return('BIGINT')
    allow(prompt).to receive(:yes?).and_return(false)
    expect(RubyMysqlTui::InputHandler::TableExecutor)
      .to receive(:execute_modify_column).with(state, client, 'test_table', 'age', 'BIGINT NOT NULL').and_return(state)

    result = described_class.handle_modify_column(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'returns state unchanged when no column is selected' do
    state[:records] = []
    result = described_class.handle_modify_column(state, client, prompt)
    expect(result).to eq(state)
  end

  it 'handles Mysql2::Error' do
    allow(prompt).to receive(:select).and_return('BIGINT')
    allow(prompt).to receive(:yes?).and_return(true)
    allow(RubyMysqlTui::InputHandler::TableExecutor)
      .to receive(:execute_modify_column).and_raise(Mysql2::Error.new('Error'))
    expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

    result = described_class.handle_modify_column(state, client, prompt)
    expect(result).to eq(state)
  end
end

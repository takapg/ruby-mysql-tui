# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'ruby_mysql_tui/input_handler/sql'

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.handle_sql_text_input' do
    let(:state) { { sql_input: 'SELECT * ' } }

    it 'appends normal characters to sql_input' do
      event = double('Event', key: double('Key', name: :unknown), value: 'F')
      new_state = described_class.handle_sql_text_input(event, state).first
      expect(new_state[:sql_input]).to eq('SELECT * F')
    end

    it 'ignores values starting with escape character \e' do
      event = double('Event', key: double('Key', name: :unknown), value: "\e[A")
      new_state = described_class.handle_sql_text_input(event, state).first
      expect(new_state[:sql_input]).to eq('SELECT * ')
    end

    it 'handles backspace correctly' do
      event = double('Event', key: double('Key', name: :backspace), value: nil)
      new_state = described_class.handle_sql_text_input(event, state).first
      expect(new_state[:sql_input]).to eq('SELECT *')
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.update_sql_history' do
    let(:state) { { sql_history: [] } }

    it 'adds SQL to history when empty' do
      described_class.update_sql_history('SELECT 1', state)
      expect(state[:sql_history]).to eq(['SELECT 1'])
    end

    it 'adds SQL to history when different from last' do
      state[:sql_history] = ['SELECT 1']
      described_class.update_sql_history('SELECT 2', state)
      expect(state[:sql_history]).to eq(['SELECT 1', 'SELECT 2'])
    end

    it 'does not add empty or blank SQL to history' do
      described_class.update_sql_history('', state)
      described_class.update_sql_history('   ', state)
      expect(state[:sql_history]).to eq([])
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.update_sql_history (duplicates and limits)' do
    let(:state) { { sql_history: [] } }

    it 'moves existing SQL to the end of history' do
      state[:sql_history] = ['SELECT 1', 'SELECT 2']
      described_class.update_sql_history('SELECT 1', state)
      expect(state[:sql_history]).to eq(['SELECT 2', 'SELECT 1'])
    end

    it 'limits history to MAX_HISTORY_SIZE' do
      state[:sql_history] = (1..100).map { |i| "SELECT #{i}" }
      described_class.update_sql_history('SELECT 101', state)
      expect(state[:sql_history].size).to eq(100)
      expect(state[:sql_history].first).to eq('SELECT 2')
      expect(state[:sql_history].last).to eq('SELECT 101')
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.update_sql_history persistence' do
    let(:state) { { sql_history: [] } }

    it 'saves history to file when a new SQL is added' do
      expect(RubyMysqlTui::InputHandler::SqlHistoryManager).to receive(:save_history)
      described_class.update_sql_history('SELECT 1', state)
    end

    it 'does not save history when SQL is duplicate' do
      state[:sql_history] = ['SELECT 1']
      expect(RubyMysqlTui::InputHandler::SqlHistoryManager).not_to receive(:save_history)
      described_class.update_sql_history('SELECT 1', state)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.handle_sql_history_up' do
    let(:state) { { sql_history: %w[SQL1 SQL2], sql_input: 'current', sql_history_index: nil } }

    it 'sets the latest history and saves current input' do
      new_state = described_class.handle_sql_history_up(state).first
      expect(new_state[:sql_input]).to eq('SQL2')
      expect(new_state[:sql_history_index]).to eq(1)
      expect(new_state[:sql_temp_input]).to eq('current')
    end

    it 'decrements index when already browsing history' do
      state[:sql_history_index] = 1
      state[:sql_temp_input] = 'original'
      new_state = described_class.handle_sql_history_up(state).first
      expect(new_state[:sql_input]).to eq('SQL1')
      expect(new_state[:sql_history_index]).to eq(0)
      expect(new_state[:sql_temp_input]).to eq('original')
    end

    it 'does nothing when history is empty' do
      state[:sql_history] = []
      new_state = described_class.handle_sql_history_up(state).first
      expect(new_state[:sql_input]).to eq('current')
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.handle_sql_history_down' do
    let(:state) do
      {
        sql_history: %w[SQL1 SQL2], sql_input: 'SQL1',
        sql_history_index: 0, sql_temp_input: 'current'
      }
    end

    it 'increments index' do
      new_state = described_class.handle_sql_history_down(state).first
      expect(new_state[:sql_input]).to eq('SQL2')
      expect(new_state[:sql_history_index]).to eq(1)
    end

    it 'restores temp input when reaching the end of history' do
      state[:sql_history_index] = 1
      new_state = described_class.handle_sql_history_down(state).first
      expect(new_state[:sql_input]).to eq('current')
      expect(new_state[:sql_history_index]).to be_nil
    end

    it 'does nothing when index is nil' do
      state[:sql_history_index] = nil
      new_state = described_class.handle_sql_history_down(state).first
      expect(new_state[:sql_input]).to eq('SQL1')
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.execute_sql (basic)' do
    let(:client) { double('Client', query: [], list_databases: ['db1'], list_tables: ['t1']) }
    let(:state) { { sql_history: [], sql_history_index: 1 } }

    it 'resets sql_history_index to nil after execution' do
      described_class.execute_sql('SELECT 1', state, client)
      expect(state[:sql_history_index]).to be_nil
    end

    it 'refreshes items when no database is selected' do
      state[:selected_database] = nil
      described_class.execute_sql('CREATE DATABASE db2', state, client)
      expect(client).to have_received(:list_databases)
      expect(state[:items]).to eq(['db1'])
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.execute_sql (refresh)' do
    let(:client) { double('Client', query: [], list_databases: ['db1'], list_tables: ['t1']) }
    let(:state) { { sql_history: [], sql_history_index: 1 } }

    it 'refreshes items when a database is selected' do
      state[:selected_db] = 'db1'
      described_class.execute_sql('CREATE TABLE t2 (id int)', state, client)
      expect(client).to have_received(:list_tables).with('db1')
      expect(state[:items]).to eq(['t1'])
    end

    it 'refresh_items でエラーが発生してもクラッシュせず、現在のアイテムリストを維持する' do
      state[:selected_db] = 'db1'
      state[:items] = ['t1']
      allow(client).to receive(:list_tables).with('db1').and_raise(StandardError.new('DB gone'))
      expect(RubyMysqlTui.logger).to receive(:error).with(/Failed to refresh items: DB gone/)

      described_class.execute_sql('DROP DATABASE db1', state, client)
      expect(state[:items]).to eq(['t1'])
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.execute_sql (USE statement) success' do
    let(:client) { double('Client', query: [], list_tables: %w[t1 t2]) }
    let(:state) { { sql_history: [], selected_db: 'old_db' } }

    it 'updates selected_db and switches to tables view' do
      described_class.execute_sql('USE new_db', state, client)
      expect(state[:selected_db]).to eq('new_db')
      expect(state[:view_mode]).to eq(:tables)
      expect(state[:items]).to eq(%w[t1 t2])
      expect(state[:sql_result_mode]).to be false
    end

    it 'handles USE with backticks' do
      described_class.execute_sql('USE `new_db`', state, client)
      expect(state[:selected_db]).to eq('new_db')
    end

    it 'handles USE case-insensitively' do
      described_class.execute_sql('use new_db', state, client)
      expect(state[:selected_db]).to eq('new_db')
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.execute_sql (USE statement) edge cases' do
    let(:client) { double('Client', query: [], list_tables: %w[t1 t2]) }
    let(:state) { { sql_history: [], selected_db: 'old_db' } }

    it 'handles USE with backticks and spaces in database name' do
      described_class.execute_sql('USE `my database`', state, client)
      expect(state[:selected_db]).to eq('my database')
    end

    it 'does not update selected_db when USE statement fails' do
      allow(client).to receive(:query).with('USE non_existent_db').and_return([{ 'Error' => 'Unknown database' }])
      described_class.execute_sql('USE non_existent_db', state, client)
      expect(state[:selected_db]).to eq('old_db')
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.query_mysql (success)' do
    let(:client) { double('Client', affected_rows: 1, last_id: 0) }

    it 'returns results when client.query returns data' do
      allow(client).to receive(:query).and_return([{ 'id' => 1 }])
      expect(described_class.query_mysql('SELECT 1', client)).to eq([{ 'id' => 1 }])
    end

    it 'returns affected rows message when client.query returns nil' do
      allow(client).to receive(:query).and_return(nil)
      expect(described_class.query_mysql('UPDATE users SET name="Bob"', client))
        .to eq([{ 'Result' => 'Query OK, 1 rows affected' }])
    end

    it 'includes last_id in message when present' do
      allow(client).to receive(:query).and_return(nil)
      allow(client).to receive(:last_id).and_return(100)
      expect(described_class.query_mysql('INSERT INTO users...', client))
        .to eq([{ 'Result' => 'Query OK, 1 rows affected (last id: 100)' }])
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.query_mysql (error)' do
    let(:client) { double('Client') }

    it 'returns error message when an exception occurs' do
      allow(client).to receive(:query).and_raise(StandardError.new('SQL Error'))
      expect(described_class.query_mysql('INVALID SQL', client)).to eq([{ 'Error' => 'SQL Error' }])
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::SqlHistoryManager do
  let(:temp_file) { Tempfile.new('ruby_mysql_tui_history_test') }
  before { stub_const('RubyMysqlTui::InputHandler::SqlHistoryManager::HISTORY_FILE', temp_file.path) }
  after { temp_file.unlink }

  describe '.load_history' do
    it 'reads history from the file' do
      history = ['SELECT 1', 'SELECT 2']
      File.write(temp_file.path, "#{history.join("\n")}\n")
      expect(described_class.load_history).to eq(history)
    end

    it 'returns an empty array and logs error when File.readlines fails' do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:readlines).and_raise(StandardError.new('Read error'))
      expect(RubyMysqlTui.logger).to receive(:error).with(/Failed to load SQL history: Read error/)
      expect(described_class.load_history).to eq([])
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::SqlHistoryManager do
  let(:temp_file) { Tempfile.new('ruby_mysql_tui_history_test') }
  before { stub_const('RubyMysqlTui::InputHandler::SqlHistoryManager::HISTORY_FILE', temp_file.path) }
  after { temp_file.unlink }

  describe '.save_history' do
    it 'writes history to the file' do
      history = ['SELECT 1', 'SELECT 2']
      described_class.save_history(history)
      expect(File.readlines(temp_file.path, chomp: true)).to eq(history)
    end

    it 'logs error when File.open fails' do
      allow(File).to receive(:open).and_raise(StandardError.new('Write error'))
      expect(RubyMysqlTui.logger).to receive(:error).with(/Failed to save SQL history: Write error/)
      expect { described_class.save_history(['SQL1']) }.not_to raise_error
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.process_sql_keypress' do
    let(:state) { { sql_input: 'SELECT 1' } }
    let(:client) { double('Client') }

    it 'calls open_external_editor when :ctrl_e is pressed' do
      event = double('Event', key: double('Key', name: :ctrl_e), value: nil)
      expect(described_class).to receive(:open_external_editor).and_return([{ sql_input: 'SELECT 2' }, false])
      described_class.process_sql_keypress(event, state, client)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.open_external_editor' do
    let(:state) { { sql_input: 'SELECT 1' } }

    it 'updates sql_input when editor returns content' do
      allow(described_class).to receive(:edit_in_editor).and_return('SELECT 2')
      new_state, redraw = described_class.open_external_editor(state)
      expect(new_state[:sql_input]).to eq('SELECT 2')
      expect(redraw).to be true
    end

    it 'keeps sql_input when editor returns nil' do
      allow(described_class).to receive(:edit_in_editor).and_return(nil)
      new_state, _redraw = described_class.open_external_editor(state)
      expect(new_state[:sql_input]).to eq('SELECT 1')
    end

    it 'uses ENV["EDITOR"] if set' do
      allow(ENV).to receive(:[]).with('EDITOR').and_return('code')
      expect(described_class).to receive(:edit_in_editor).with('code', 'SELECT 1').and_return('SELECT 2')
      described_class.open_external_editor(state)
    end

    it 'defaults to vi if ENV["EDITOR"] is not set' do
      allow(ENV).to receive(:[]).with('EDITOR').and_return(nil)
      expect(described_class).to receive(:edit_in_editor).with('vi', 'SELECT 1').and_return('SELECT 2')
      described_class.open_external_editor(state)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.edit_in_editor' do
    let(:editor) { 'vi' }
    let(:content) { 'SELECT 1' }

    it 'calls system with separate arguments to prevent injection' do
      expect(described_class).to receive(:system).with(editor, kind_of(String)).and_return(true)
      allow(File).to receive(:read).and_return('SELECT 2')
      result = described_class.edit_in_editor(editor, content)
      expect(result).to eq('SELECT 2')
    end

    it 'returns nil if system returns false' do
      expect(described_class).to receive(:system).with(editor, kind_of(String)).and_return(false)
      result = described_class.edit_in_editor(editor, content)
      expect(result).to be_nil
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::SqlHistoryManager do
  let(:temp_file) { Tempfile.new('ruby_mysql_tui_history_test') }
  before { stub_const('RubyMysqlTui::InputHandler::SqlHistoryManager::HISTORY_FILE', temp_file.path) }
  after { temp_file.unlink }

  describe '.clear_history' do
    it 'deletes the history file if it exists' do
      File.write(temp_file.path, "SELECT 1\n")
      expect(File).to exist(temp_file.path)
      described_class.clear_history
      expect(File).not_to exist(temp_file.path)
    end

    it 'does not raise error when file does not exist' do
      FileUtils.rm_f(temp_file.path)
      expect { described_class.clear_history }.not_to raise_error
    end

    it 'logs error when FileUtils.rm_f fails' do
      allow(FileUtils).to receive(:rm_f).and_raise(StandardError.new('Delete error'))
      expect(RubyMysqlTui.logger).to receive(:error).with(/Failed to clear SQL history: Delete error/)
      expect { described_class.clear_history }.not_to raise_error
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.handle_sql_history_clear' do
    let(:state) { { sql_history: %w[SQL1 SQL2], sql_history_index: 1 } }

    it 'clears sql_history and resets sql_history_index' do
      allow(RubyMysqlTui::InputHandler::SqlHistoryManager).to receive(:clear_history)
      new_state, _redraw = described_class.handle_sql_history_clear(state)
      expect(new_state[:sql_history]).to eq([])
      expect(new_state[:sql_history_index]).to be_nil
    end

    it 'calls SqlHistoryManager.clear_history' do
      expect(RubyMysqlTui::InputHandler::SqlHistoryManager).to receive(:clear_history)
      described_class.handle_sql_history_clear(state)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler, type: :module do
  describe '.process_sql_keypress with ctrl_k' do
    let(:state) { { sql_history: %w[SQL1 SQL2], sql_history_index: 1, sql_input: 'SELECT' } }
    let(:client) { double('Client') }

    it 'handles ctrl_k by clearing history' do
      event = double('Event', key: double('Key', name: :ctrl_k), value: nil)
      allow(RubyMysqlTui::InputHandler::SqlHistoryManager).to receive(:clear_history)
      new_state, _redraw = described_class.process_sql_keypress(event, state, client)
      expect(new_state[:sql_history]).to eq([])
      expect(new_state[:sql_history_index]).to be_nil
    end
  end
end

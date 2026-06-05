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

    it 'does not add duplicate SQL to history' do
      state[:sql_history] = ['SELECT 1']
      described_class.update_sql_history('SELECT 1', state)
      expect(state[:sql_history]).to eq(['SELECT 1'])
    end

    it 'does not add empty or blank SQL to history' do
      described_class.update_sql_history('', state)
      described_class.update_sql_history('   ', state)
      expect(state[:sql_history]).to eq([])
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
  describe '.execute_sql' do
    let(:client) { double('Client', query: []) }
    let(:state) { { sql_history: [], sql_history_index: 1 } }

    it 'resets sql_history_index to nil after execution' do
      described_class.execute_sql('SELECT 1', state, client)
      expect(state[:sql_history_index]).to be_nil
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

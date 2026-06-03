# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
require 'ruby_mysql_tui/input_handler/record_manager'

require_relative '../support/record_manager_setup'

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record' do
  include_context 'record manager setup'

  it 'retries record editing when an error occurs' do
    Timeout.timeout(10) do
      state[:selected_table] = 'users'
      state[:records] = [{ 'id' => '1', 'name' => 'Alice' }]
      state[:selected_record_index] = 0
      allow(client).to receive(:primary_key_for).with('users').and_return('id')

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

  it 'returns state if primary key is not found' do
    Timeout.timeout(10) do
      allow(client).to receive(:primary_key_for).and_return(nil)
      expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_create_record' do
  include_context 'record manager setup'

  it 'prompts for all columns and inserts a record' do
    Timeout.timeout(10) do
      allow(client).to receive(:list_columns).with('users').and_return(%w[id name])
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
      allow(prompt).to receive(:ask).and_return('val')
      allow(prompt).to receive(:say)

      error = Mysql2::Error.new('Persistent failure')
      allow(error).to receive(:errno).and_return(1062)
      expect(client).to receive(:insert_record).exactly(5).times.and_raise(error)

      described_class.handle_create_record(state, client, prompt)
    end
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_create_record error handling' do
  include_context 'record manager setup'

  it 'handles MySQL error during insertion' do
    Timeout.timeout(10) do
      allow(client).to receive(:list_columns).and_return(%w[id])
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

  it 'stops record creation when user declines retry after error' do
    Timeout.timeout(10) do
      allow(client).to receive(:list_columns).and_return(%w[id])
      allow(prompt).to receive(:ask).and_return('invalid', nil)
      allow(client).to receive(:insert_record).and_raise(Mysql2::Error, 'Insert failed')
      expect(prompt).to receive(:say).with(/挿入に失敗しました/, color: :red)

      described_class.handle_create_record(state, client, prompt)
    end
  end
end

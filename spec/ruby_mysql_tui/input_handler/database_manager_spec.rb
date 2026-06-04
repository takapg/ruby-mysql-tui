# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/ruby_mysql_tui/input_handler/database_manager'

RSpec.describe RubyMysqlTui::InputHandler::DatabaseManager do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:state) { { items: ['db1', 'db2'], selected_index: 0 } }

  describe '.handle_create_database' do
    it 'creates a database when a valid name is provided' do
      allow(prompt).to receive(:ask).and_return('new_db')
      expect(client).to receive(:create_database).with('new_db')
      expect(client).to receive(:list_databases).and_return(['db1', 'db2', 'new_db'])

      result = described_class.handle_create_database(state, client, prompt)
      expect(result[:items]).to eq(['db1', 'db2', 'new_db'])
    end

    it 'returns state unchanged when name is empty' do
      allow(prompt).to receive(:ask).and_return('  ')
      result = described_class.handle_create_database(state, client, prompt)
      expect(result).to eq(state)
    end

    it 'handles Mysql2::Error' do
      allow(prompt).to receive(:ask).and_return('new_db')
      allow(client).to receive(:create_database).and_raise(Mysql2::Error.new('Error'))
      expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

      result = described_class.handle_create_database(state, client, prompt)
      expect(result).to eq(state)
    end
  end

  describe '.handle_drop_database' do
    it 'drops a database when confirmed' do
      allow(prompt).to receive(:yes?).and_return(true)
      expect(client).to receive(:drop_database).with('db1')
      expect(client).to receive(:list_databases).and_return(['db2'])

      result = described_class.handle_drop_database(state, client, prompt)
      expect(result[:items]).to eq(['db2'])
      expect(result[:status_message]).to eq("Database 'db1' deleted successfully")
    end

    it 'cancels deletion when not confirmed' do
      allow(prompt).to receive(:yes?).and_return(false)
      result = described_class.handle_drop_database(state, client, prompt)
      expect(result[:status_message]).to eq('Deletion cancelled')
    end

    it 'handles Mysql2::Error' do
      allow(prompt).to receive(:yes?).and_return(true)
      allow(client).to receive(:drop_database).and_raise(Mysql2::Error.new('Error'))
      expect(prompt).to receive(:error).with(/エラーが発生しました: Error/)

      result = described_class.handle_drop_database(state, client, prompt)
      expect(result).to eq(state)
    end
  end
end

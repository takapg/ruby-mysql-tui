# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/record_manager'

RSpec.describe RubyMysqlTui::InputHandler::RecordManager do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:table_name) { 'users' }
  let(:pk_column) { 'id' }
  let(:record) { { 'id' => 1, 'name' => 'Alice' } }
  let(:state) do
    {
      focus: :right,
      view_mode: :records,
      selected_table: table_name,
      selected_record_index: 0,
      records: [record],
      records_offset: 0
    }
  end

  describe '.handle_edit_record guards' do
    context 'when record management is not possible' do
      it 'returns state immediately if focus is :left' do
        state[:focus] = :left
        expect(client).not_to receive(:primary_key_for)
        expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
      end

      it 'returns state immediately if view_mode is not :records' do
        state[:view_mode] = :tables
        expect(client).not_to receive(:primary_key_for)
        expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
      end

      it 'returns state immediately if records are nil' do
        state[:records] = nil
        expect(client).not_to receive(:primary_key_for)
        expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
      end
    end

    it 'returns state if primary key is not found' do
      allow(client).to receive(:primary_key_for).and_return(nil)
      expect(described_class.handle_edit_record(state, client, prompt)).to eq(state)
    end
  end
end

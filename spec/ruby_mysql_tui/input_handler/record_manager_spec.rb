# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/record_manager'

require_relative '../support/record_manager_setup'

RSpec.describe RubyMysqlTui::InputHandler::RecordManager, '.handle_edit_record guards' do
  include_context 'record manager setup'
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

# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler'
require 'ruby_mysql_tui/input_handler/record_manager'

RSpec.describe RubyMysqlTui::InputHandler do
  let(:state) { { focus: :right, view_mode: :records, records: [{ 'id' => 1 }] } }
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:event) { double('Event', value: 'e', key: double('Key')) }

  describe '.handle_input' do
    it 'calls RecordManager.handle_edit_record when the "e" key is pressed' do
      prompt = instance_double('TTY::Prompt')
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      expect(RubyMysqlTui::InputHandler::RecordManager).to receive(:handle_edit_record).with(state, client, prompt)

      RubyMysqlTui::InputHandler.handle_input(event, state, client)
    end

    it 'toggles view_mode between :records and :table_structure when "i" key is pressed' do
      state = { focus: :right, view_mode: :records, selected_table: 'users', records: [] }
      event = double('Event', value: 'i', key: double('Key'))

      allow(client).to receive(:list_table_structure).with('users').and_return([{ 'Field' => 'id' }])

      new_state = RubyMysqlTui::InputHandler.handle_input(event, state, client)
      expect(new_state[:view_mode]).to eq(:table_structure)
      expect(new_state[:records]).to eq([{ 'Field' => 'id' }])

      event_back = double('Event', value: 'i', key: double('Key'))
      allow(client).to receive(:list_records).with('users', 0).and_return([{ 'id' => 1 }])

      final_state = RubyMysqlTui::InputHandler.handle_input(event_back, new_state, client)
      expect(final_state[:view_mode]).to eq(:records)
      expect(final_state[:records]).to eq([{ 'id' => 1 }])
    end

    context 'when arrow keys are pressed' do
      let(:state) { { focus: :left, items: ['item1', 'item2'], selected_index: 0 } }

      it 'handles "down" key via event.key.name' do
        event = double('Event', key: double('Key', name: 'down'))
        new_state = RubyMysqlTui::InputHandler.handle_input(event, state, client)
        expect(new_state[:selected_index]).to eq(1)
      end

      it 'handles "up" key via event.name' do
        state[:selected_index] = 1
        event = double('Event', name: 'up')
        new_state = RubyMysqlTui::InputHandler.handle_input(event, state, client)
        expect(new_state[:selected_index]).to eq(0)
      end
    end
  end

  describe '.extract_key_name' do
    it 'extracts name from event.key.name' do
      event = double('Event', key: double('Key', name: 'up'))
      expect(RubyMysqlTui::InputHandler.extract_key_name(event)).to eq('up')
    end

    it 'extracts name from event.name' do
      event = double('Event', name: 'down')
      expect(RubyMysqlTui::InputHandler.extract_key_name(event)).to eq('down')
    end

    it 'returns nil if neither is present' do
      event = double('Event')
      expect(RubyMysqlTui::InputHandler.extract_key_name(event)).to be_nil
    end
  end
end

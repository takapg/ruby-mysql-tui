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
  end
end

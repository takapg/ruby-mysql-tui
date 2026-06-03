# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler'

RSpec.describe RubyMysqlTui::InputHandler do
  let(:state) { { focus: :right, view_mode: :records, records: [{ 'id' => 1 }] } }
  let(:client) { instance_double('RubyMysqlTui::Client') }

  describe '.handle_input' do
    context 'when arrow key escape sequences are provided' do
      it 'calls handle_up for "\e[A" and "\eOA"' do
        expect(RubyMysqlTui::InputHandler).to receive(:handle_up).with(state, client).and_return(state)
        RubyMysqlTui::InputHandler.handle_input(double('Event', value: "\e[A"), state, client)

        expect(RubyMysqlTui::InputHandler).to receive(:handle_up).with(state, client).and_return(state)
        RubyMysqlTui::InputHandler.handle_input(double('Event', value: "\eOA"), state, client)
      end

      it 'calls handle_down for "\e[B" and "\eOB"' do
        expect(RubyMysqlTui::InputHandler).to receive(:handle_down).with(state, client).and_return(state)
        RubyMysqlTui::InputHandler.handle_input(double('Event', value: "\e[B"), state, client)

        expect(RubyMysqlTui::InputHandler).to receive(:handle_down).with(state, client).and_return(state)
        RubyMysqlTui::InputHandler.handle_input(double('Event', value: "\eOB"), state, client)
      end
    end
  end
end

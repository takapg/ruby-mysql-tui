# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler'

RSpec.describe RubyMysqlTui::InputHandler do
  let(:client) { instance_double('RubyMysqlTui::Client') }

  describe '.handle_input' do
    context 'when arrow keys are pressed' do
      let(:state) { { focus: :left, items: %w[item1 item2], selected_index: 0 } }

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
end

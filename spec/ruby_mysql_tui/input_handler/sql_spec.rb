# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/sql'

RSpec.describe RubyMysqlTui::InputHandler do
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

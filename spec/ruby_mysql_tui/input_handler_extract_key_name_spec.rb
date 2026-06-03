# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler'

RSpec.describe RubyMysqlTui::InputHandler do
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

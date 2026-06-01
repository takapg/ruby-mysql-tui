# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/ruby_mysql_tui'

RSpec.describe RubyMysqlTui do
  describe '.handle_input' do
    it 'Tabキーが押されたとき、フォーカスを :left から :right に切り替える' do
      expect(RubyMysqlTui.handle_input("\t", :left)).to eq(:right)
    end

    it 'Tabキーが押されたとき、フォーカスを :right から :left に切り替える' do
      expect(RubyMysqlTui.handle_input("\t", :right)).to eq(:left)
    end

    it 'Tab以外のキーが押されたとき、フォーカス :left を維持する' do
      expect(RubyMysqlTui.handle_input('a', :left)).to eq(:left)
    end

    it 'Tab以外のキーが押されたとき、フォーカス :right を維持する' do
      expect(RubyMysqlTui.handle_input('b', :right)).to eq(:right)
    end
  end
end

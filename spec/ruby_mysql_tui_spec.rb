# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/ruby_mysql_tui'

RSpec.describe RubyMysqlTui do
  describe '.handle_input' do
    let(:client) { double('Client') }
    let(:tab_event) { double('Event', key: double('Key', name: :tab)) }
    let(:other_event) { double('Event', key: double('Key', name: :other)) }

    it 'Tabキーが押されたとき、フォーカスを :left から :right に切り替える' do
      state = { focus: :left }
      expect(RubyMysqlTui.handle_input(tab_event, state, client)[:focus]).to eq(:right)
    end

    it 'Tabキーが押されたとき、フォーカスを :right から :left に切り替える' do
      state = { focus: :right }
      expect(RubyMysqlTui.handle_input(tab_event, state, client)[:focus]).to eq(:left)
    end

    it 'Tab以外のキーが押されたとき、フォーカス :left を維持する' do
      state = { focus: :left }
      expect(RubyMysqlTui.handle_input(other_event, state, client)[:focus]).to eq(:left)
    end

    it 'Tab以外のキーが押されたとき、フォーカス :right を維持する' do
      state = { focus: :right }
      expect(RubyMysqlTui.handle_input(other_event, state, client)[:focus]).to eq(:right)
    end
  end
end

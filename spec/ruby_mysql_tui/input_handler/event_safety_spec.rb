# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyMysqlTui::InputHandler, 'Event Handling Safety' do
  let(:client) { double('Client') }
  let(:state) { { focus: :left, items: [], view_mode: :databases, sql_mode: false } }

  describe '.handle_input' do
    it 'does not raise NoMethodError when event is a String' do
      expect do
        described_class.handle_input('a', state, client)
      end.not_to raise_error
    end

    it 'correctly handles event objects that respond to :value' do
      event = double('Event', value: 'b')
      # 'b' は Navigation.handle_back_navigation を呼び出し、状態ハッシュを返す
      expect(described_class.handle_input(event, state, client)).to be_a(Hash)
    end
  end
end

RSpec.describe RubyMysqlTui, 'Event Handling Safety' do
  let(:client) { double('Client') }
  let(:state) { { focus: :left, items: [], view_mode: :databases, sql_mode: false } }

  describe '.handle_loop_input' do
    let(:reader) { double('TTY::Reader') }

    it 'does not raise NoMethodError when reader.read_keypress returns a String' do
      allow(reader).to receive(:read_keypress).and_return('a')
      expect do
        described_class.handle_loop_input(reader, state, client)
      end.not_to raise_error
    end

    it 'correctly handles reader.read_keypress returning an event object' do
      event = double('Event', value: 'q')
      allow(reader).to receive(:read_keypress).and_return(event)
      # 'q' は [state, true] を返してループを終了させる
      result = described_class.handle_loop_input(reader, state, client)
      expect(result).to eq([state, true])
    end
  end
end

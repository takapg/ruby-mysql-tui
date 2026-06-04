# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler'
require 'ruby_mysql_tui/input_handler/record_manager'

RSpec.describe RubyMysqlTui::InputHandler, '.handle_input - edit' do
  let(:state) { { focus: :right, view_mode: :records, records: [{ 'id' => 1 }] } }
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:event) { double('Event', value: 'e', key: double('Key')) }

  it 'calls RecordManager.handle_edit_record when the "e" key is pressed' do
    prompt = instance_double('TTY::Prompt')
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    expect(RubyMysqlTui::InputHandler::RecordManager).to receive(:handle_edit_record).with(state, client, prompt)

    RubyMysqlTui::InputHandler.handle_input(event, state, client)
  end
end

RSpec.describe RubyMysqlTui::InputHandler, '.handle_input - toggle' do
  let(:client) { instance_double('RubyMysqlTui::Client') }

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
end

RSpec.describe RubyMysqlTui::InputHandler, '.handle_input - structure scroll' do
  let(:client) { instance_double('RubyMysqlTui::Client') }

  it 'updates records_offset when scrolling in :table_structure mode' do
    state = { focus: :right, view_mode: :table_structure, records: [1, 2, 3], records_offset: 0 }

    # 下方向へのスクロール
    event_down = double('Event', value: "\e[B", key: double('Key'))
    state = RubyMysqlTui::InputHandler.handle_input(event_down, state, client)
    expect(state[:records_offset]).to eq(1)

    # 上方向へのスクロール (0に戻る)
    event_up = double('Event', value: "\e[A", key: double('Key'))
    state = RubyMysqlTui::InputHandler.handle_input(event_up, state, client)
    expect(state[:records_offset]).to eq(0)

    # 上方向へのスクロール (0未満にならないこと)
    state = RubyMysqlTui::InputHandler.handle_input(event_up, state, client)
    expect(state[:records_offset]).to eq(0)

    # 最大値までスクロール
    3.times do
      state = RubyMysqlTui::InputHandler.handle_input(event_down, state, client)
    end
    expect(state[:records_offset]).to eq(3)

    # 最大値を超えないこと
    state = RubyMysqlTui::InputHandler.handle_input(event_down, state, client)
    expect(state[:records_offset]).to eq(3)
  end
end

RSpec.describe RubyMysqlTui::InputHandler, '.handle_input - column scroll' do
  let(:client) { instance_double('RubyMysqlTui::Client') }

  it 'increments columns_offset when scrolling right' do
    state = { focus: :right, view_mode: :records, records: [{ 'a' => 1, 'b' => 2, 'c' => 3 }], columns_offset: 0 }
    event_right = double('Event', value: "\e[C", key: double('Key'))

    state = RubyMysqlTui::InputHandler.handle_input(event_right, state, client)
    expect(state[:columns_offset]).to eq(1)
    state = RubyMysqlTui::InputHandler.handle_input(event_right, state, client)
    expect(state[:columns_offset]).to eq(2)
  end

  it 'decrements columns_offset when scrolling left' do
    state = { focus: :right, view_mode: :records, records: [{ 'a' => 1, 'b' => 2, 'c' => 3 }], columns_offset: 2 }
    event_left = double('Event', value: "\e[D", key: double('Key'))

    state = RubyMysqlTui::InputHandler.handle_input(event_left, state, client)
    expect(state[:columns_offset]).to eq(1)
  end

  it 'clamps columns_offset between 0 and max' do
    state = { focus: :right, view_mode: :records, records: [{ 'a' => 1, 'b' => 2, 'c' => 3 }], columns_offset: 0 }
    event_left = double('Event', value: "\e[D", key: double('Key'))
    event_right = double('Event', value: "\e[C", key: double('Key'))

    state = RubyMysqlTui::InputHandler.handle_input(event_left, state, client)
    expect(state[:columns_offset]).to eq(0)

    state = { focus: :right, view_mode: :records, records: [{ 'a' => 1, 'b' => 2, 'c' => 3 }], columns_offset: 2 }
    state = RubyMysqlTui::InputHandler.handle_input(event_right, state, client)
    expect(state[:columns_offset]).to eq(2)
  end
end

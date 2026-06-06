# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler'
require 'ruby_mysql_tui/input_handler/record_manager'
require 'ruby_mysql_tui/input_handler/navigation'

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

RSpec.describe RubyMysqlTui::InputHandler, '.handle_input - record detail navigation (next)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }

  it 'increments selected_record_index and resets detail_offset when "]" is pressed' do
    state = {
      view_mode: :record_detail,
      selected_record_index: 0,
      records: [{}, {}, {}],
      detail_offset: 5
    }
    event = double('Event', value: ']', key: double('Key'))

    new_state = RubyMysqlTui::InputHandler.handle_input(event, state, client)
    expect(new_state[:selected_record_index]).to eq(1)
    expect(new_state[:detail_offset]).to eq(0)
  end
end

RSpec.describe RubyMysqlTui::InputHandler, '.handle_input - record detail navigation (prev)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }

  it 'decrements selected_record_index and resets detail_offset when "[" is pressed' do
    state = {
      view_mode: :record_detail,
      selected_record_index: 1,
      records: [{}, {}, {}],
      detail_offset: 5
    }
    event = double('Event', value: '[', key: double('Key'))

    new_state = RubyMysqlTui::InputHandler.handle_input(event, state, client)
    expect(new_state[:selected_record_index]).to eq(0)
    expect(new_state[:detail_offset]).to eq(0)
  end
end

RSpec.describe RubyMysqlTui::InputHandler, '.handle_input - record detail navigation (clamp)' do
  let(:client) { instance_double('RubyMysqlTui::Client') }

  it 'clamps selected_record_index within the range of records' do
    state = {
      view_mode: :record_detail,
      selected_record_index: 2,
      records: [{}, {}, {}],
      detail_offset: 0
    }
    event_next = double('Event', value: ']', key: double('Key'))
    expect(RubyMysqlTui::InputHandler.handle_input(event_next, state, client)[:selected_record_index]).to eq(2)

    state[:selected_record_index] = 0
    event_prev = double('Event', value: '[', key: double('Key'))
    expect(RubyMysqlTui::InputHandler.handle_input(event_prev, state, client)[:selected_record_index]).to eq(0)
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

RSpec.describe RubyMysqlTui::InputHandler, '.handle_input - help' do
  let(:client) { double('Client') }
  let(:state) { { focus: :left, items: %w[db1 db2], filter_query: '', selected_index: 0 } }

  it 'sets show_help to true when "?" is pressed' do
    event = double('Event', value: '?', key: double('Key'))
    new_state = described_class.handle_input(event, state, client)
    expect(new_state[:show_help]).to be true
  end

  it 'sets show_help to false when any key is pressed while show_help is true' do
    state_with_help = state.merge(show_help: true)
    event = double('Event', value: 'a', key: double('Key'))
    new_state = described_class.handle_input(event, state_with_help, client)
    expect(new_state[:show_help]).to be false
  end
end

RSpec.describe RubyMysqlTui::InputHandler, 'left pane' do
  let(:client) { double('Client') }
  let(:state) { { focus: :left, items: %w[db1 db2], filter_query: '', selected_index: 0 } }

  it '/ キーが押されたとき、プロンプトを表示し filter_query を更新すること' do
    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('test_query')

    new_state = described_class.handle_input('/', state, client)

    expect(new_state[:filter_query]).to eq('test_query')
    expect(new_state[:selected_index]).to eq(0)
  end

  it 'Esc キー (\e) が押され、filter_query が設定されているとき、フィルタをクリアすること' do
    state_with_filter = state.merge(filter_query: 'some_query', selected_index: 2)
    new_state = described_class.handle_input("\e", state_with_filter, client)

    expect(new_state[:filter_query]).to eq('')
    expect(new_state[:selected_index]).to eq(0)
  end

  it 'Esc キー (\e) が押されたが、filter_query が空のときは状態を変更しないこと' do
    new_state = described_class.handle_input("\e", state, client)
    expect(new_state).to eq(state)
  end
end

RSpec.describe RubyMysqlTui::InputHandler, 'right pane' do
  let(:client) { double('Client') }

  it '/ キーが押されたとき、プロンプトを表示し records_filter_query を更新すること' do
    state = { focus: :right, view_mode: :records, records: [], records_filter_query: '' }
    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('record_query')

    new_state = described_class.handle_input('/', state, client)

    expect(new_state[:records_filter_query]).to eq('record_query')
  end

  it 'Esc キー (\e) が押され、records_filter_query が設定されているとき、フィルタをクリアすること' do
    state = { focus: :right, view_mode: :records, records: [], records_filter_query: 'some_query' }
    new_state = described_class.handle_input("\e", state, client)

    expect(new_state[:records_filter_query]).to eq('')
  end
end

RSpec.describe RubyMysqlTui::InputHandler::Navigation, '.handle_databases_return' do
  let(:client) { instance_double('RubyMysqlTui::Client') }

  it 'データベースからテーブル一覧へ遷移する際、filter_query をリセットすること' do
    state = {
      view_mode: :databases,
      items: ['test_db'],
      selected_index: 0,
      filter_query: 'test'
    }
    allow(client).to receive(:select_database).with('test_db')
    allow(client).to receive(:list_tables).with('test_db').and_return(['table1'])

    RubyMysqlTui::InputHandler::Navigation.handle_databases_return(state, client)
    expect(state[:filter_query]).to eq('')
  end
end

RSpec.describe RubyMysqlTui::InputHandler::Navigation, '.handle_back_navigation' do
  let(:client) { instance_double('RubyMysqlTui::Client') }

  it 'データベース一覧に戻る際、filter_query をリセットすること' do
    state = {
      view_mode: :tables,
      filter_query: 'some_filter'
    }
    allow(client).to receive(:list_databases).and_return(%w[db1 db2])

    RubyMysqlTui::InputHandler::Navigation.handle_back_navigation(state, client)
    expect(state[:filter_query]).to eq('')
  end
end

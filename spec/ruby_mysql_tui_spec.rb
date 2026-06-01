# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/ruby_mysql_tui'

RSpec.describe RubyMysqlTui, '.handle_input (focus)' do
  let(:client) { double('Client') }
  let(:tab_event) { double('Event', value: nil, key: double('Key', name: :tab)) }
  let(:other_event) { double('Event', value: nil, key: double('Key', name: :other)) }

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

RSpec.describe RubyMysqlTui, '.handle_input (navigation)' do
  let(:client) { double('Client') }
  context '方向キーによる選択移動' do
    let(:up_event) { double('Event', value: nil, key: double('Key', name: :up)) }
    let(:down_event) { double('Event', value: nil, key: double('Key', name: :down)) }

    it 'Upキーが押されたとき、フォーカス :left で selected_index を減少させる' do
      state = { focus: :left, selected_index: 1, items: %w[a b] }
      expect(RubyMysqlTui.handle_input(up_event, state, client)[:selected_index]).to eq(0)
    end

    it 'Downキーが押されたとき、フォーカス :left で selected_index を増加させる' do
      state = { focus: :left, selected_index: 0, items: %w[a b] }
      expect(RubyMysqlTui.handle_input(down_event, state, client)[:selected_index]).to eq(1)
    end

    it 'Upキーが押されたとき、selected_index が 0 の場合は 0 を維持する' do
      state = { focus: :left, selected_index: 0, items: %w[a b] }
      expect(RubyMysqlTui.handle_input(up_event, state, client)[:selected_index]).to eq(0)
    end

    it 'Downキーが押されたとき、selected_index が末尾の場合は末尾を維持する' do
      state = { focus: :left, selected_index: 1, items: %w[a b] }
      expect(RubyMysqlTui.handle_input(down_event, state, client)[:selected_index]).to eq(1)
    end
  end
end

RSpec.describe RubyMysqlTui, '.handle_input (selection)' do
  let(:client) { double('Client') }
  context 'EnterキーによるDB確定' do
    let(:return_event) { double('Event', value: nil, key: double('Key', name: :return)) }

    it 'フォーカス :left かつ view_mode :databases のとき、テーブル一覧に遷移する' do
      state = { focus: :left, view_mode: :databases, items: %w[db1], selected_index: 0 }
      allow(client).to receive(:list_tables).with('db1').and_return(%w[table1 table2])

      result = RubyMysqlTui.handle_input(return_event, state, client)
      expect(result[:view_mode]).to eq(:tables)
      expect(result[:selected_db]).to eq('db1')
      expect(result[:items]).to eq(%w[table1 table2])
      expect(result[:selected_index]).to eq(0)
    end

    it 'フォーカス :left かつ view_mode :tables のとき、レコード一覧に遷移する' do
      state = { focus: :left, view_mode: :tables, items: %w[table1], selected_index: 0 }
      records = [{ 'id' => 1, 'name' => 'Alice' }]
      allow(client).to receive(:list_records).with('table1').and_return(records)

      result = RubyMysqlTui.handle_input(return_event, state, client)
      expect(result[:view_mode]).to eq(:records)
      expect(result[:selected_table]).to eq('table1')
      expect(result[:records]).to eq(records)
    end
  end
end

RSpec.describe RubyMysqlTui, '.handle_input (back navigation)' do
  let(:client) { double('Client') }
  let(:back_event) { double('Event', value: 'b', key: double('Key', name: :unknown)) }

  it 'bキーが押されたとき、:tables ビューから :databases ビューに戻る' do
    state = { view_mode: :tables, items: %w[table1], selected_index: 0 }
    allow(client).to receive(:list_databases).and_return(%w[db1 db2])

    result = RubyMysqlTui.handle_input(back_event, state, client)
    expect(result[:view_mode]).to eq(:databases)
    expect(result[:items]).to eq(%w[db1 db2])
    expect(result[:selected_index]).to eq(0)
  end

  it 'bキーが押されたとき、:records ビューから :databases ビューに戻る' do
    state = { view_mode: :records, records: [], selected_index: 0 }
    allow(client).to receive(:list_databases).and_return(%w[db1 db2])

    result = RubyMysqlTui.handle_input(back_event, state, client)
    expect(result[:view_mode]).to eq(:databases)
    expect(result[:items]).to eq(%w[db1 db2])
  end
end

RSpec.describe RubyMysqlTui, '.handle_input (sql_mode)' do
  let(:client) { double('Client') }
  let(:s_event) { double('Event', value: 's', key: double('Key', name: :unknown)) }

  it 'sキーが押されたとき、sql_mode を切り替える' do
    state = { sql_mode: false }
    expect(RubyMysqlTui.handle_input(s_event, state, client)[:sql_mode]).to eq(true)
  end
end

RSpec.describe RubyMysqlTui::InputHandler, '.execute_sql' do
  let(:client) { double('Client') }
  let(:sql) { 'SELECT * FROM users' }
  let(:results) { [{ 'id' => 1, 'name' => 'Alice' }] }

  it 'SQLを実行し、結果を records に格納して view_mode を :records に変更する' do
    state = { sql_mode: true }
    allow(client).to receive(:query).with(sql).and_return(results)

    result = RubyMysqlTui::InputHandler.execute_sql(sql, state, client)
    expect(result[:records]).to eq(results)
    expect(result[:view_mode]).to eq(:records)
    expect(result[:sql_mode]).to eq(false)
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (SQL mode)' do
  let(:client) { double('Client') }
  let(:reader) { double('Reader') }

  it 'sキーでSQLモードに入り、SQLを入力して実行し、通常モードに戻る一連の流れを検証する' do
    allow(client).to receive(:list_databases).and_return([])
    state = RubyMysqlTui.initial_state(client)

    # 1. 's' キーで SQL モードへ
    s_event = double('Event', value: 's', key: double('Key', name: :unknown))
    state = RubyMysqlTui.handle_input(s_event, state, client)
    expect(state[:sql_mode]).to eq(true)

    # 2. SQL 入力と実行
    sql = 'SELECT * FROM users'
    results = [{ 'id' => 1, 'name' => 'Alice' }]
    allow(client).to receive(:query).with(sql).and_return(results)

    # handle_loop_input を使用して SQL モード時の挙動をシミュレート
    allow(reader).to receive(:read_line).with('').and_return(sql)

    new_state, should_break = RubyMysqlTui.handle_loop_input(reader, state, client)

    expect(new_state[:records]).to eq(results)
    expect(new_state[:view_mode]).to eq(:records)
    expect(new_state[:sql_mode]).to eq(false)
    expect(should_break).to eq(false)
  end
end

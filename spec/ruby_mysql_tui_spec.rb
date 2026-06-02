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

RSpec.describe RubyMysqlTui, '.handle_input (record scroll - basic)' do
  let(:client) { double('Client') }
  let(:up_event) { double('Event', value: nil, key: double('Key', name: :up)) }
  let(:down_event) { double('Event', value: nil, key: double('Key', name: :down)) }

  it '右ペインフォーカスかつレコードビューのとき、Upキーで records_offset を減少させる' do
    state = { focus: :right, view_mode: :records, records: Array.new(100), records_offset: 10 }
    expect(RubyMysqlTui.handle_input(up_event, state, client)[:records_offset]).to eq(9)
  end

  it '右ペインフォーカスかつレコードビューのとき、Downキーで records_offset を増加させる' do
    state = { focus: :right, view_mode: :records, records: Array.new(100), records_offset: 10 }
    expect(RubyMysqlTui.handle_input(down_event, state, client)[:records_offset]).to eq(11)
  end
end

RSpec.describe RubyMysqlTui, '.handle_input (record scroll - boundaries)' do
  let(:client) { double('Client') }
  let(:up_event) { double('Event', value: nil, key: double('Key', name: :up)) }
  let(:down_event) { double('Event', value: nil, key: double('Key', name: :down)) }

  it 'records_offset が 0 未満にならないこと' do
    state = { focus: :right, view_mode: :records, records: Array.new(100), records_offset: 0 }
    expect(RubyMysqlTui.handle_input(up_event, state, client)[:records_offset]).to eq(0)
  end

  it 'Downキーで records_offset が正しく増加すること' do
    state = {
      focus: :right,
      view_mode: :records,
      selected_table: 'users',
      records: Array.new(1000),
      records_offset: 10
    }
    expect(RubyMysqlTui.handle_input(down_event, state, client)[:records_offset]).to eq(11)
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
      allow(client).to receive(:list_records).with('table1', 0).and_return(records)

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

  it 'SQL実行時にエラーが発生した場合、エラーメッセージを records に格納する' do
    state = { sql_mode: true }
    allow(client).to receive(:query).with(sql).and_raise(StandardError, 'Query Error')

    result = RubyMysqlTui::InputHandler.execute_sql(sql, state, client)
    expect(result[:records]).to eq([{ 'Error' => 'Query Error' }])
    expect(result[:view_mode]).to eq(:records)
  end
end

RSpec.describe RubyMysqlTui::InputHandler, '.process_sql_keypress' do
  let(:client) { double('Client') }
  let(:state) { { sql_mode: true, sql_input: '' } }

  it 'Escキーが押されたとき、sql_mode を false にし、入力をクリアする' do
    event = double('Event', value: nil, key: double('Key', name: :escape))
    result, _should_break = RubyMysqlTui::InputHandler.process_sql_keypress(event, state, client)
    expect(result[:sql_mode]).to eq(false)
    expect(result[:sql_input]).to eq('')
  end

  it 'qキーが押されたとき、即座に sql_mode を false にし、入力をクリアする' do
    event = double('Event', value: 'q', key: double('Key', name: :unknown))
    result, _should_break = RubyMysqlTui::InputHandler.process_sql_keypress(event, state, client)
    expect(result[:sql_mode]).to eq(false)
    expect(result[:sql_input]).to eq('')
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (SQL mode) - Transition' do
  let(:client) { double('Client') }
  let(:initial_state) { RubyMysqlTui.initial_state(client) }

  before { allow(client).to receive(:list_databases).and_return([]) }

  it 'sキーでSQLモードに移行できること' do
    s_event = double('Event', value: 's', key: double('Key', name: :unknown))
    state = RubyMysqlTui.handle_input(s_event, initial_state, client)
    expect(state[:sql_mode]).to eq(true)
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (Pagination - Down)' do
  let(:client) { double('Client') }
  let(:initial_state) { RubyMysqlTui.initial_state(client) }

  before { allow(client).to receive(:list_databases).and_return([]) }

  it '100件以上のレコードがあるとき、Downキーで次ページをフェッチする' do
    state = initial_state.merge(
      focus: :right,
      view_mode: :records,
      selected_table: 'users',
      records: Array.new(100) { { 'id' => 0 } },
      page_offset: 0,
      records_offset: 99
    )

    next_page = Array.new(100) { { 'id' => 1 } }
    allow(client).to receive(:list_records).with('users', 100).and_return(next_page)

    down_event = double('Event', value: nil, key: double('Key', name: :down))
    result = RubyMysqlTui.handle_input(down_event, state, client)

    expect(result[:records_offset]).to eq(100)
    expect(result[:page_offset]).to eq(100)
    expect(result[:records]).to eq(next_page)
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (Pagination - Down Boundary)' do
  let(:client) { double('Client') }
  let(:initial_state) { RubyMysqlTui.initial_state(client) }

  before { allow(client).to receive(:list_databases).and_return([]) }

  it '最後のページの最後のレコードに達しているとき、Downキーを押しても records_offset が増加せず、データも更新されないこと' do
    state = initial_state.merge(
      focus: :right,
      view_mode: :records,
      selected_table: 'users',
      records: Array.new(50) { { 'id' => 0 } },
      page_offset: 100,
      records_offset: 149
    )

    allow(client).to receive(:list_records).with('users', 150).and_return([])

    down_event = double('Event', value: nil, key: double('Key', name: :down))
    result = RubyMysqlTui.handle_input(down_event, state, client)

    expect(result[:records_offset]).to eq(149)
    expect(result[:records]).to eq(Array.new(50) { { 'id' => 0 } })
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (Pagination - Up - Page Offset)' do
  let(:client) { double('Client') }
  let(:initial_state) { RubyMysqlTui.initial_state(client) }
  before { allow(client).to receive(:list_databases).and_return([]) }

  it 'ページオフセットがあるとき、Upキーで前ページをフェッチする' do
    state = initial_state.merge(
      focus: :right,
      view_mode: :records,
      selected_table: 'users',
      records: Array.new(100) { { 'id' => 1 } },
      page_offset: 100,
      records_offset: 100
    )

    prev_page = Array.new(100) { { 'id' => 0 } }
    allow(client).to receive(:list_records).with('users', 0).and_return(prev_page)

    up_event = double('Event', value: nil, key: double('Key', name: :up))
    result = RubyMysqlTui.handle_input(up_event, state, client)

    expect(result[:records_offset]).to eq(99)
    expect(result[:page_offset]).to eq(0)
    expect(result[:records]).to eq(prev_page)
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (Pagination - Up - Empty Next Page)' do
  let(:client) { double('Client') }
  let(:initial_state) { RubyMysqlTui.initial_state(client) }
  before { allow(client).to receive(:list_databases).and_return([]) }

  it '次ページが空の場合、records_offset が前ページの末尾に固定され、page_offset は更新されないこと' do
    state = initial_state.merge(
      focus: :right,
      view_mode: :records,
      selected_table: 'users',
      records: Array.new(100) { { 'id' => 0 } },
      page_offset: 0,
      records_offset: 99
    )

    allow(client).to receive(:list_records).with('users', 100).and_return([])

    down_event = double('Event', value: nil, key: double('Key', name: :down))
    result = RubyMysqlTui.handle_input(down_event, state, client)

    expect(result[:records_offset]).to eq(99)
    expect(result[:page_offset]).to eq(0)
    expect(result[:records]).to eq(Array.new(100) { { 'id' => 0 } })
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (Pagination - Up - Small Record Set)' do
  let(:client) { double('Client') }
  let(:initial_state) { RubyMysqlTui.initial_state(client) }
  before { allow(client).to receive(:list_databases).and_return([]) }

  it 'レコード総数が PAGE_SIZE 未満のとき、Downキーでフェッチが発生しないこと' do
    state = initial_state.merge(
      focus: :right,
      view_mode: :records,
      selected_table: 'users',
      records: Array.new(50) { { 'id' => 0 } },
      page_offset: 0,
      records_offset: 10
    )

    expect(client).not_to receive(:list_records)

    down_event = double('Event', value: nil, key: double('Key', name: :down))
    result = RubyMysqlTui.handle_input(down_event, state, client)

    expect(result[:records_offset]).to eq(11)
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (SQL mode) - Execution' do
  let(:client) { double('Client') }
  let(:reader) { double('Reader') }
  let(:initial_state) { RubyMysqlTui.initial_state(client) }

  before { allow(client).to receive(:list_databases).and_return([]) }

  it 'SQLを入力して実行し、結果が反映されて通常モードに戻ること' do
    state = initial_state.merge(sql_mode: true)
    sql = 'SELECT * FROM users'
    results = [{ 'id' => 1, 'name' => 'Alice' }]
    allow(client).to receive(:query).with(sql).and_return(results)

    events = sql.chars.map { |c| double('Event', value: c, key: double('Key', name: :unknown)) }
    events << double('Event', value: nil, key: double('Key', name: :return))
    allow(reader).to receive(:read_keypress).and_return(*events)

    current_state = state
    loop do
      current_state = RubyMysqlTui.handle_loop_input(reader, current_state, client).first
      break unless current_state[:sql_mode]
    end

    expect(current_state[:records]).to eq(results)
    expect(current_state[:view_mode]).to eq(:records)
    expect(current_state[:sql_mode]).to eq(false)
  end
end

RSpec.describe RubyMysqlTui, 'Integration flow (Record Deletion)' do
  let(:client) { double('Client') }
  let(:delete_event) { double('Event', value: 'd', key: double('Key', name: :unknown)) }
  let(:state) do
    { focus: :right, view_mode: :records, selected_table: 'users',
      records: [{ 'id' => 1, 'name' => 'Alice' }], selected_record_index: 0, records_offset: 0 }
  end

  before do
    allow(client).to receive(:primary_key_for).with('users').and_return('id')
    allow(client).to receive(:list_records).and_return([])
  end

  it 'ユーザーが承認した場合、レコードを削除する' do
    allow_any_instance_of(TTY::Prompt).to receive(:yes?).and_return(true)
    expect(client).to receive(:delete_record).with('users', 'id', 1)

    RubyMysqlTui.handle_input(delete_event, state, client)
  end

  it 'ユーザーが拒否した場合、レコードを削除しない' do
    allow_any_instance_of(TTY::Prompt).to receive(:yes?).and_return(false)
    expect(client).not_to receive(:delete_record)

    RubyMysqlTui.handle_input(delete_event, state, client)
  end
end

RSpec.describe 'Happy Path Integration', 'Real MySQL' do
  let(:client) { RubyMysqlTui::Client.new(database: 'tui_test_db') }
  let(:return_event) { double('Event', value: nil, key: double('Key', name: :return)) }

  before(:all) do
    # 管理者権限でテストDBを作成
    admin_client = RubyMysqlTui::Client.new(database: nil)
    admin_client.query('CREATE DATABASE IF NOT EXISTS tui_test_db')

    # テストDBに接続してテーブルを作成し、データを投入
    test_client = RubyMysqlTui::Client.new(database: 'tui_test_db')
    test_client.query('CREATE TABLE IF NOT EXISTS test_table (id INT PRIMARY KEY, name VARCHAR(255))')
    test_client.query('TRUNCATE TABLE test_table')
    test_client.query('INSERT INTO test_table (id, name) VALUES (1, "Alice"), (2, "Bob")')
  end

  it 'ハッピーパス: データベース選択 -> テーブル選択 -> レコード表示 の遷移が正しく行われること' do
    # 1. 初期状態 (データベース一覧)
    state = RubyMysqlTui.initial_state(client)
    expect(state[:view_mode]).to eq(:databases)
    expect(state[:items]).to include('tui_test_db')

    # tui_test_db を選択して Enter
    state[:selected_index] = state[:items].index('tui_test_db')
    state = RubyMysqlTui.handle_input(return_event, state, client)

    # 2. テーブル一覧ビューに遷移
    expect(state[:view_mode]).to eq(:tables)
    expect(state[:items]).to include('test_table')

    # test_table を選択して Enter
    state[:selected_index] = state[:items].index('test_table')
    state = RubyMysqlTui.handle_input(return_event, state, client)

    # 3. レコードビューに遷移し、データが取得できていること
    expect(state[:view_mode]).to eq(:records)
    expect(state[:records].size).to eq(2)
    expect(state[:records].any? { |r| r['name'] == 'Alice' }).to be true
    expect(state[:records].any? { |r| r['name'] == 'Bob' }).to be true
  end
end

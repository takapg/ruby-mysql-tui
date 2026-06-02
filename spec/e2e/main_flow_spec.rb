require 'spec_helper'
require_relative 'e2e_helper'
require 'ruby_mysql_tui'

RSpec.describe 'E2E Main Flow' do
  before(:all) do
    E2EHelper.setup_test_db
  end

  after(:all) do
    E2EHelper.cleanup_test_db
  end

  let(:client) { RubyMysqlTui::Client.new(host: ENV.fetch('MYSQL_HOST', '127.0.0.1'), database: E2EHelper::TEST_DB) }
  let(:reader) { instance_double(TTY::Reader) }

  it 'navigates from databases to tables to records' do
    # TTY::Reader.new がモックされた reader を返すように設定
    allow(TTY::Reader).to receive(:new).and_return(reader)

    # シミュレートするキー入力シーケンス:
    # 1. Down (DB選択)
    # 2. Enter (DB決定)
    # 3. Down (テーブル選択)
    # 4. Enter (テーブル決定)
    # 5. 'q' (終了)
    events = [
      double('Event', value: "\e[B", key: double('Key', name: :down)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\e[B", key: double('Key', name: :down)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    # 内部状態の遷移を追跡するために handle_input をラップして記録する
    states = [RubyMysqlTui.initial_state(client)]
    allow(RubyMysqlTui).to receive(:handle_input).and_wrap_original do |m, *args|
      res = m.call(*args)
      states << res
      res
    end

    # 期待されるクエリが発行されることを検証
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    expect(client).to receive(:list_tables).with(E2EHelper::TEST_DB).and_call_original
    expect(client).to receive(:list_records).with('test_table', 0).and_call_original

    # メインループを実行
    RubyMysqlTui.run_main_loop(client)

    # 状態遷移の検証
    # 1. 初期状態 (databases)
    # 2. DB選択後 (tables)
    # 3. テーブル選択後 (records)
    expect(states.any? { |s| s[:view_mode] == :databases }).to be true
    expect(states.any? { |s| s[:view_mode] == :tables }).to be true
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end

  it 'switches focus using Tab key' do
    allow(TTY::Reader).to receive(:new).and_return(reader)

    # Tabキーを押し、その後に 'q' で終了
    events = [
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    states = []
    allow(RubyMysqlTui).to receive(:handle_input).and_wrap_original do |m, *args|
      res = m.call(*args)
      states << res
      res
    end

    initial_focus = RubyMysqlTui.initial_state(client)[:focus]
    RubyMysqlTui.run_main_loop(client)

    # フォーカスが切り替わっていることを検証 (例: :left -> :right)
    expect(states.last[:focus]).not_to eq(initial_focus)
  end
end

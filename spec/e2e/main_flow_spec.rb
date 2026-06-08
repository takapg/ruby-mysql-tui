# frozen_string_literal: true

require 'spec_helper'
require_relative 'e2e_helper'
require 'ruby_mysql_tui'

module E2EEventHelpers
  def make_event(value, key_name)
    double('Event', value: value, key: double('Key', name: key_name))
  end

  def retry_events
    [
      make_event("\r", :return),
      make_event("\r", :return),
      make_event("\t", :tab),
      make_event('n', :n),
      make_event('q', :q)
    ]
  end

  def setup_edit_events(reader)
    events = [
      make_event("\r", :return),
      make_event("\r", :return),
      make_event("\t", :tab),
      make_event('e', :e),
      make_event('q', :q)
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)
  end

  def detail_edit_events
    [
      make_event("\r", :return),
      make_event("\r", :return),
      make_event("\t", :tab),
      make_event("\r", :return),
      make_event("\e[B", :down), # 編集可能なフィールドに移動
      make_event('e', :e),
      make_event('q', :q)
    ]
  end

  def detail_delete_events
    [
      make_event("\r", :return),
      make_event("\r", :return),
      make_event("\t", :tab),
      make_event("\r", :return),
      make_event('d', :d),
      make_event('q', :q)
    ]
  end

  def external_edit_events
    [
      make_event("\r", :return),
      make_event("\r", :return),
      make_event("\t", :tab),
      make_event("\r", :return),
      make_event("\e[B", :down),
      make_event("\x05", :ctrl_e),
      make_event('q', :q)
    ]
  end

  def all_records_events
    [
      make_event("\r", :return),
      make_event("\r", :return),
      make_event("\t", :tab),
      make_event('a', :a),
      make_event('a', :a),
      make_event('q', :q)
    ]
  end

  def sql_history_events
    data = [
      ['s', :s], ['S', :unknown], ['E', :unknown], ['L', :unknown],
      ['E', :unknown], ['C', :unknown], ['T', :unknown], [' ', :unknown],
      ['1', :unknown], ["\r", :return], ['s', :s], ["\e[A", :up],
      ["\r", :return], ['q', :q]
    ]
    data.map { |val, key| make_event(val, key) }
  end
end

module E2EFlowHelpers
  def track_states(client)
    states = [RubyMysqlTui.initial_state(client).dup]
    allow(RubyMysqlTui).to receive(:handle_input).and_wrap_original do |m, *args|
      res = m.call(*args)
      states << res.dup if res.is_a?(Hash)
      res
    end
    states
  end

  def setup_retry_reader(reader)
    allow(TTY::Reader).to receive(:new).and_return(reader)
    allow(reader).to receive(:read_keypress).and_return(*retry_events)
  end

  def setup_retry_prompt
    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('invalid', 'valid')
    allow(prompt).to receive(:say)
    prompt
  end

  def setup_record_creation_retry_mocks(reader)
    setup_retry_reader(reader)
    setup_retry_prompt
  end

  def setup_record_edit_retry_mocks(reader, prompt)
    setup_edit_events(reader)
    setup_edit_prompt_mocks(prompt)
  end

  def setup_basic_client_mocks(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([])
  end

  def setup_client_for_type_validation(client, column)
    setup_basic_client_mocks(client)
    allow(client).to receive(:list_columns).and_return([column])
    structure = [{ 'Field' => column, 'Type' => 'int(11)', 'Null' => 'NO' }]
    allow(client).to receive(:list_table_structure).and_return(structure)
  end

  def setup_edit_prompt_mocks(prompt)
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('duplicate_id', 'valid_id')
    allow(prompt).to receive(:say)
  end

  def setup_filtering_mocks(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    records = [
      { 'id' => 1, 'name' => 'Alice' },
      { 'id' => 2, 'name' => 'Bob' }
    ]
    allow(client).to receive(:list_records).and_return(records)
  end
end

RSpec.shared_context 'e2e setup' do
  include E2EFlowHelpers
  include E2EEventHelpers

  before(:all) { E2EHelper.setup_test_db }
  after(:all) { E2EHelper.cleanup_test_db }
  let(:client) { RubyMysqlTui::Client.new(host: ENV.fetch('MYSQL_HOST', '127.0.0.1'), database: E2EHelper::TEST_DB) }
  let(:reader) { instance_double(TTY::Reader) }
end

RSpec.describe 'E2E Navigation' do
  include_context 'e2e setup'

  it 'navigates from databases to tables to records' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)
    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    expect(client).to receive(:list_tables).with(E2EHelper::TEST_DB).and_call_original
    expect(client).to receive(:list_records).with('test_table', 0).and_call_original
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :databases }).to be true
    expect(states.any? { |s| s[:view_mode] == :tables }).to be true
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Focus' do
  include_context 'e2e setup'

  it 'switches focus using Tab key' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)
    states = track_states(client)
    initial_focus = RubyMysqlTui.initial_state(client)[:focus]
    RubyMysqlTui.run_main_loop(client)
    expected_focus = initial_focus == :left ? :right : :left
    expect(states.last[:focus]).to eq(expected_focus)
  end
end

RSpec.describe 'E2E Record Creation - Basic' do
  include_context 'e2e setup'

  it 'creates a new record when n is pressed' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    # 1. DB選択 -> 2. テーブル選択 -> 3. 新規作成(n) -> 4. 終了(q)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'n', key: double('Key', name: :n)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    # TTY::Prompt のモック
    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('test_value')

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([])
    allow(client).to receive(:list_columns).and_return(['col1'])
    expect(client).to receive(:insert_record).with('test_table', { 'col1' => 'test_value' })

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Record Edit - NULL value' do
  include_context 'e2e setup'

  it 'updates a nullable column to NULL when empty input is provided' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    setup_edit_events(reader)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:select).and_return('nullable_col')
    allow(prompt).to receive(:ask).and_return('NULL') # 明示的NULL入力
    allow(prompt).to receive(:say)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'nullable_col' => 'some_value' }])
    allow(client).to receive(:primary_key_for).and_return('id')
    allow(client).to receive(:list_table_structure).and_return(
      [
        { 'Field' => 'id', 'Null' => 'NO', 'Key' => 'PRI' },
        { 'Field' => 'nullable_col', 'Null' => 'YES', 'Key' => '' }
      ]
    )

    expect(client).to receive(:update_record).with(anything, anything, anything, 'nullable_col', nil)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Record Creation - Cancel Retry' do
  include_context 'e2e setup'

  it 'cancels record creation retry when an error occurs' do
    setup_retry_reader(reader)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('invalid', nil)
    allow(prompt).to receive(:say)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([])
    allow(client).to receive(:list_columns).and_return(['col1'])
    error = Mysql2::Error.new('Invalid value')
    allow(error).to receive(:errno).and_return(1062)
    expect(client).to receive(:insert_record)
      .with('test_table', { 'col1' => 'invalid' })
      .and_raise(error)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Record Creation - Retry' do
  include_context 'e2e setup'

  it 'retries record creation when an error occurs' do
    setup_record_creation_retry_mocks(reader)
    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([])
    allow(client).to receive(:list_columns).and_return(['col1'])

    error = Mysql2::Error.new('Invalid value')
    allow(error).to receive(:errno).and_return(1062)
    expect(client).to receive(:insert_record)
      .with('test_table', { 'col1' => 'invalid' })
      .and_raise(error)
    expect(client).to receive(:insert_record).with('test_table', { 'col1' => 'valid' }).and_return(true)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Record Edit - Duplicate PK' do
  include_context 'e2e setup'

  it 'retries record update when a duplicate primary key error occurs' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    setup_record_edit_retry_mocks(reader, prompt)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')

    # 1回目は 1062 エラー、2回目は成功
    error = Mysql2::Error.new('Duplicate entry')
    allow(error).to receive(:errno).and_return(1062)

    expect(client).to receive(:update_record).with('test_table', 'id', 1, 'name', 'duplicate_id').and_raise(error)
    expect(client).to receive(:update_record).with('test_table', 'id', 1, 'name', 'valid_id').and_return(true)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Record Edit - NOT NULL Validation' do
  include_context 'e2e setup'

  it 'applies required validation for NOT NULL columns during record edit' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)

    setup_edit_events(reader)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')
    allow(client).to receive(:list_table_structure).and_return([{ 'Field' => 'name', 'Null' => 'NO' }])

    # NOT NULLカラム 'name' に対してバリデーションが設定されていることを検証
    allow(prompt).to receive(:select).and_return('name')
    expect(prompt).to receive(:ask).with(/新しい値を入力してください \(name\):/, any_args) do |*_args, &block|
      question = instance_double('TTY::Prompt::Question')
      expect(question).to receive(:required).with(true)
      expect(question).to receive(:validate).with(/\S+/, '入力してください')
      block.call(question)
      'valid_name'
    end
    allow(prompt).to receive(:say)

    expect(client).to receive(:update_record).with('test_table', 'id', 1, 'name', 'valid_name')

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Record Creation - NULL value' do
  include_context 'e2e setup'

  it 'inserts NULL when empty input is provided for nullable column' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'n', key: double('Key', name: :n)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    # Nullableなカラムに対して明示的にNULLを入力
    allow(prompt).to receive(:ask).and_return('NULL')

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([])
    allow(client).to receive(:list_columns).and_return(['nullable_col'])
    allow(client).to receive(:list_table_structure).and_return([{ 'Field' => 'nullable_col', 'Null' => 'YES' }])

    expect(client).to receive(:insert_record).with('test_table', { 'nullable_col' => nil })

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Record Creation - Type Validation' do
  include_context 'e2e setup'

  it 'applies type validation for INT columns during record creation' do
    setup_retry_reader(reader)
    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)

    expect(prompt).to receive(:ask).with(/値を入力してください \(age\):/, any_args) do |*_args, &block|
      question = instance_double('TTY::Prompt::Question')
      expect(question).to receive(:required).with(true)
      expect(question).to receive(:validate).with(/\S+/, '入力してください')
      expect(question).to receive(:validate).with(/\A-?\d+\z/, '数値のみ入力してください')
      block.call(question)
      '25'
    end

    states = track_states(client)
    setup_client_for_type_validation(client, 'age')
    expect(client).to receive(:insert_record).with('test_table', { 'age' => '25' })

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Connection Error' do
  include_context 'e2e setup'

  it 'handles connection failure gracefully' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    # 即座に終了するように 'q' キーをシミュレート
    allow(reader).to receive(:read_keypress).and_return(
      double('Event', value: 'q', key: double('Key', name: :q))
    )

    # 接続エラーをシミュレート
    allow(client).to receive(:list_databases).and_raise(Mysql2::Error.new('Connection failed'))

    expect { RubyMysqlTui.run_main_loop(client) }.not_to raise_error
  end
end

RSpec.describe 'E2E Database Creation - Success' do
  include_context 'e2e setup'

  it 'creates a new database when n is pressed in database view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: 'n', key: double('Key', name: :n)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('new_e2e_db')

    expect(client).to receive(:list_databases).thrice.and_return([E2EHelper::TEST_DB])
    expect(client).to receive(:create_database).with('new_e2e_db')
    states = track_states(client)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :databases }).to be true
  end
end

RSpec.describe 'E2E Database Creation - Error' do
  include_context 'e2e setup'

  it 'handles error when creating a database with a duplicate name' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: 'n', key: double('Key', name: :n)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('duplicate_db')
    expect(prompt).to receive(:error).with(/エラーが発生しました: Database already exists/)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    error = Mysql2::Error.new('Database already exists')
    expect(client).to receive(:create_database).with('duplicate_db').and_raise(error)

    expect(RubyMysqlTui.logger).to receive(:error).with(/Database Creation Error: Database already exists/)

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :databases }).to be true
  end
end

RSpec.describe 'E2E All Records Mode' do
  include_context 'e2e setup'

  it 'toggles all records mode and fetches all records when a is pressed' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    allow(reader).to receive(:read_keypress).and_return(*all_records_events)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).with('test_table', 0, anything).and_return([{ 'id' => 1 }])
    allow(client).to receive(:list_records).with('test_table', 0).and_return([{ 'id' => 1 }])

    all_records = [{ 'id' => 1 }, { 'id' => 2 }, { 'id' => 3 }]
    expect(client).to receive(:list_records).with('test_table', 0, hash_including(limit: RubyMysqlTui::Client::MAX_RECORDS_LIMIT)).and_return(all_records)
    expect(client).to receive(:list_records).with('test_table', 0, anything).and_return([{ 'id' => 1 }])
    expect(client).to receive(:list_records).with('test_table', 0).and_return([{ 'id' => 1 }])

    RubyMysqlTui.run_main_loop(client)

    expect(states.any? { |s| s[:all_records_mode] == true && s[:records] == all_records }).to be true
    expect(states.last[:all_records_mode]).to be false
  end
end

RSpec.describe 'E2E Table Creation' do
  include_context 'e2e setup'

  it 'creates a new table when n is pressed in table view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    # 1. DB選択 -> 2. テーブル作成(n) -> 3. 終了(q)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: 'n', key: double('Key', name: :n)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('new_e2e_table', 'col1')
    allow(prompt).to receive(:select).and_return('INT')
    allow(prompt).to receive(:yes?).with('NULLを許容しますか？').and_return(false)
    allow(prompt).to receive(:yes?).with('さらにカラムを追加しますか？').and_return(false)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(%w[existing_table new_e2e_table])
    expect(client).to receive(:create_table).with('new_e2e_table', [{ name: 'col1', type: 'INT NOT NULL' }])

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :tables }).to be true
  end
end

RSpec.describe 'E2E Database Deletion' do
  include_context 'e2e setup'

  it 'deletes a database when d is pressed in database view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: 'd', key: double('Key', name: :d)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:yes?).and_return(true)

    expect(client).to receive(:list_databases).at_least(:once).and_return([E2EHelper::TEST_DB])
    expect(client).to receive(:drop_database).with(E2EHelper::TEST_DB)
    states = track_states(client)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:status_message] == "Database '#{E2EHelper::TEST_DB}' deleted successfully" }).to be true
  end
end

RSpec.describe 'E2E Record Detail View' do
  include_context 'e2e setup'

  it 'navigates from records to detail and back' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: "\r", key: double('Key', name: :return)), # Detail
      double('Event', value: 'b', key: double('Key', name: :b)),       # Back
      double('Event', value: 'q', key: double('Key', name: :q)) # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :record_detail }).to be true
    expect(states.last[:view_mode]).to eq(:records)
  end
end

RSpec.describe 'E2E Record Cloning' do
  include_context 'e2e setup'

  it 'clones a record when c is pressed in records view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: 'c', key: double('Key', name: :c)),       # Clone
      double('Event', value: 'q', key: double('Key', name: :q)) # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    # 既存レコード { 'id' => 1, 'name' => 'Alice' } がある想定
    # prompt_for_record_data が呼ばれ、値を入力して確定させる
    allow(prompt).to receive(:ask).and_return('2', 'Alice-Cloned')

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')
    allow(client).to receive(:list_columns).and_return(%w[id name])
    allow(client).to receive(:list_table_structure).and_return([])

    expect(client).to receive(:insert_record).with('test_table', { 'id' => '2', 'name' => 'Alice-Cloned' })

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E SQL History' do
  include_context 'e2e setup'

  it 'allows recalling and executing SQL from history' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    allow(reader).to receive(:read_keypress).and_return(*sql_history_events)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    expect(client).to receive(:query).with('SELECT 1').twice.and_return([{ '1' => 1 }])

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)

    expect(states.last[:sql_history]).to include('SELECT 1')
  end
end

RSpec.describe 'E2E SQL Result Scrolling' do
  include_context 'e2e setup'

  it 'does not trigger pagination fetch when scrolling SQL results' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    # s (SQL mode) -> 'SELECT 1' -> \r (execute) -> \t (focus right) -> \e[B (down) -> q (quit)
    events = [
      make_event('s', :s),
      make_event('S', :unknown), make_event('E', :unknown), make_event('L', :unknown),
      make_event('E', :unknown), make_event('C', :unknown), make_event('T', :unknown),
      make_event(' ', :unknown), make_event('1', :unknown),
      make_event("\r", :return),
      make_event("\t", :tab),
      make_event("\e[B", :down),
      make_event('q', :q)
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    # SQL実行結果をモック
    allow(client).to receive(:query).and_return([{ '1' => 1 }])
    # スクロール時に list_records が呼ばれないことを検証
    expect(client).not_to receive(:list_records)

    RubyMysqlTui.run_main_loop(client)
  end
end

RSpec.describe 'E2E Table Rename' do
  include_context 'e2e setup'

  it 'renames a table when r is pressed in table view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: 'r', key: double('Key', name: :r)),       # Rename
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('renamed_table')

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    expect(client).to receive(:list_tables).with(E2EHelper::TEST_DB).and_return(['old_table'], ['renamed_table'])
    expect(client).to receive(:rename_table).with('old_table', 'renamed_table')

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? do |s|
      s[:status_message] == "Table 'old_table' renamed to 'renamed_table' successfully"
    end).to be true
  end
end

RSpec.describe 'E2E Record Filtering - Apply' do
  include_context 'e2e setup'

  before { setup_filtering_mocks(client) }

  it 'filters records using / key' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: '/', key: double('Key', name: :slash)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('Alice')

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)

    expect(states.any? { |s| s[:records_filter_query] == 'Alice' }).to be true
  end
end

RSpec.describe 'E2E Record Filtering - Clear' do
  include_context 'e2e setup'

  before { setup_filtering_mocks(client) }

  it 'clears filter using Esc key' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: '/', key: double('Key', name: :slash)),
      double('Event', value: "\e", key: double('Key', name: :escape)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('Alice')

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)

    expect(states.last[:records_filter_query]).to eq('')
  end
end

RSpec.describe 'E2E Help Modal' do
  include_context 'e2e setup'

  it 'opens help modal with ? and closes it with Esc' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: '?', key: double('Key', name: :question)),
      double('Event', value: "\e", key: double('Key', name: :escape)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)

    expect(states.any? { |s| s[:show_help] == true }).to be true
    expect(states.last[:show_help]).to be false
  end
end

RSpec.describe 'E2E Table Deletion' do
  include_context 'e2e setup'

  it 'deletes a table when d is pressed in table view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: 'd', key: double('Key', name: :d)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:yes?).and_return(true)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    expect(client).to receive(:drop_table).with('test_table')
    states = track_states(client)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:status_message] == "Table 'test_table' deleted successfully" }).to be true
  end
end

RSpec.describe 'E2E Table Truncation' do
  include_context 'e2e setup'

  it 'truncates a table when t is pressed in table view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: 't', key: double('Key', name: :t)),       # Truncate
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:yes?).and_return(true)

    allow(client).to receive(:list_databases).at_least(:once).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    expect(client).to receive(:truncate_table).with('test_table')

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? do |s|
      s[:status_message] == "Table 'test_table' truncated successfully"
    end).to be true
  end
end

RSpec.describe 'E2E Table Column Deletion' do
  include_context 'e2e setup'

  it 'deletes a column when d is pressed in table structure view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: 'i', key: double('Key', name: :i)),       # Structure View
      double('Event', value: 'd', key: double('Key', name: :d)),       # Drop Col
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:yes?).and_return(true)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_table_structure).and_return([{ 'Field' => 'col1', 'Key' => '' }])
    expect(client).to receive(:drop_column).with('test_table', 'col1')

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:status_message] == "Column 'col1' deleted successfully" }).to be true
  end
end

RSpec.describe 'E2E Table Column Addition' do
  include_context 'e2e setup'

  let(:events) do
    [
      make_event("\r", :return), make_event("\r", :return), make_event("\t", :tab),
      make_event('i', :i), make_event('n', :n), make_event('q', :q)
    ]
  end

  it 'adds a column when n is pressed in table structure view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('new_col')
    allow(prompt).to receive(:select).and_return('VARCHAR(255)')
    allow(prompt).to receive(:yes?).with('NULLを許容しますか？').and_return(false)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_table_structure).and_return([{ 'Field' => 'id' }, { 'Field' => 'new_col' }])
    expect(client).to receive(:add_column).with('test_table', 'new_col', 'VARCHAR(255) NOT NULL')

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:status_message] == "Column 'new_col' added to 'test_table' successfully" }).to be true
  end
end

RSpec.describe 'E2E Table Column Rename' do
  include_context 'e2e setup'

  it 'renames a column when r is pressed in table structure view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: 'i', key: double('Key', name: :i)),       # Structure View
      double('Event', value: 'r', key: double('Key', name: :r)),       # Rename Col
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('renamed_col')

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_table_structure).and_return([{ 'Field' => 'old_col' }])
    expect(client).to receive(:rename_column).with('test_table', 'old_col', 'renamed_col')

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? do |s|
      s[:status_message] == "Column 'old_col' renamed to 'renamed_col' successfully"
    end).to be true
  end
end

RSpec.describe 'E2E Table Column Modify' do # rubocop:disable Metrics/BlockLength
  include_context 'e2e setup'

  it 'modifies column type when m is pressed in structure view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: 'i', key: double('Key', name: :i)),       # Structure View
      double('Event', value: 'm', key: double('Key', name: :m)),       # Modify Col
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:select).and_return('BIGINT')
    allow(prompt).to receive(:yes?).with('NULLを許容しますか？').and_return(true)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_table_structure).and_return([{ 'Field' => 'age' }])
    expect(client).to receive(:modify_column).with('test_table', 'age', 'BIGINT NULL')

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? do |s|
      s[:status_message] == "Column 'age' modified successfully"
    end).to be true
  end
end

RSpec.describe 'E2E Record External Edit' do
  include_context 'e2e setup'

  it 'updates a long text field using Ctrl+E' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    allow(reader).to receive(:read_keypress).and_return(*external_edit_events)

    record_value = 'old content'
    records = [{ 'id' => 1, 'content' => record_value }]
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return(records)
    allow(client).to receive(:primary_key_for).and_return('id')
    allow(client).to receive(:list_table_structure).and_return(
      [
        { 'Field' => 'id', 'Type' => 'int', 'Null' => 'NO' },
        { 'Field' => 'content', 'Type' => 'text', 'Null' => 'YES' }
      ]
    )

    allow(RubyMysqlTui::InputHandler::SqlEditor).to receive(:edit_in_editor).and_return('new content')
    expect(client).to receive(:update_record).with('test_table', 'id', 1, 'content', 'new content')

    RubyMysqlTui.run_main_loop(client)
  end
end

RSpec.describe 'E2E Record Value Viewing' do
  include_context 'e2e setup'

  it 'opens the external viewer when v is pressed in detail view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: "\r", key: double('Key', name: :return)), # Detail
      double('Event', value: "\e[B", key: double('Key', name: :down)), # Move to 'content'
      double('Event', value: 'v', key: double('Key', name: :v)),       # View
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    record_value = 'This is a very long text that should be viewed in a pager'
    records = [{ 'id' => 1, 'content' => record_value }]
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return(records)

    expect(RubyMysqlTui::InputHandler::ValueViewer).to receive(:view_value).with(record_value)

    RubyMysqlTui.run_main_loop(client)
  end
end

RSpec.describe 'E2E Record Detail Log Display' do
  include_context 'e2e setup'

  it 'displays the selected column value in the log area' do
    allow(TTY::Screen).to receive(:width).and_return(100)
    allow(TTY::Screen).to receive(:height).and_return(30)
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: "\r", key: double('Key', name: :return)), # Detail
      double('Event', value: "\e[B", key: double('Key', name: :down)), # Next Column
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    records = [{ 'id' => 1, 'name' => 'Alice', 'email' => 'alice@example.com' }]
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return(records)

    expect { RubyMysqlTui.run_main_loop(client) }
      .to output(/\[Value of 'id'\]: 1.*\[Value of 'name'\]: Alice/m).to_stdout
  end
end

RSpec.describe 'E2E Record Detail Operations - Editing' do
  include_context 'e2e setup'

  it 'allows editing a record from detail view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    allow(reader).to receive(:read_keypress).and_return(*detail_edit_events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('edited_name')
    allow(prompt).to receive(:say)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')
    allow(client).to receive(:list_table_structure).and_return([])

    expect(client).to receive(:update_record).with('test_table', 'id', 1, 'name', 'edited_name')

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :record_detail }).to be true
  end
end

RSpec.describe 'E2E Record Detail Operations - Deletion' do
  include_context 'e2e setup'

  it 'allows deleting a record from detail view and returns to records view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    allow(reader).to receive(:read_keypress).and_return(*detail_delete_events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:yes?).and_return(true)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')
    expect(client).to receive(:delete_record).and_return(true)

    RubyMysqlTui.run_main_loop(client)

    # 詳細ビューにいたことが確認でき、かつ最終的にレコード一覧に戻っていることを検証
    expect(states.any? { |s| s[:view_mode] == :record_detail }).to be true
    expect(states.last[:view_mode]).to eq(:records)
  end
end

RSpec.describe 'E2E Record Detail Direct Edit' do
  include_context 'e2e setup'

  it 'allows direct editing of a field in detail view using Down and e keys' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = detail_edit_events
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('DirectlyEditedName')
    allow(prompt).to receive(:say)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')
    allow(client).to receive(:list_table_structure).and_return([])

    expect(client).to receive(:update_record).with('test_table', 'id', 1, 'name', 'DirectlyEditedName')

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :record_detail }).to be true
  end
end

RSpec.describe 'E2E Record Detail Navigation' do
  include_context 'e2e setup'

  it 'switches between records using [ and ] keys in detail view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: "\r", key: double('Key', name: :return)), # Detail
      double('Event', value: ']', key: double('Key', name: :bracket_right)), # Next
      double('Event', value: '[', key: double('Key', name: :bracket_left)),  # Prev
      double('Event', value: 'q', key: double('Key', name: :q)) # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    states = track_states(client)
    records = [{ 'id' => 1 }, { 'id' => 2 }, { 'id' => 3 }]
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return(records)

    RubyMysqlTui.run_main_loop(client)

    indices = states.filter_map { |s| s[:view_mode] == :record_detail ? s[:selected_record_index] : nil }
    # 初期(0) -> ](1) -> [(0)
    expect(indices).to include(0, 1)
    expect(indices.last).to eq(0)
  end
end

RSpec.describe 'E2E Record Detail Scrolling' do
  include_context 'e2e setup'

  it 'scrolls through columns in detail view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)), # DB
      double('Event', value: "\r", key: double('Key', name: :return)), # Table
      double('Event', value: "\t", key: double('Key', name: :tab)),    # Focus Right
      double('Event', value: "\r", key: double('Key', name: :return)), # Detail
      double('Event', value: "\e[B", key: double('Key', name: :down)), # Scroll Down
      double('Event', value: "\e[B", key: double('Key', name: :down)), # Scroll Down
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    states = track_states(client)
    record = { 'c1' => 1, 'c2' => 2, 'c3' => 3, 'c4' => 4, 'c5' => 5 }
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([record])

    RubyMysqlTui.run_main_loop(client)

    indices = states.filter_map { |s| s[:selected_column_index] }
    expect(indices).to include(0, 1, 2)
    expect(indices.last).to eq(2)
  end
end

RSpec.describe 'E2E Column Scrolling' do
  include_context 'e2e setup'

  it 'increments and decrements columns_offset when left/right keys are pressed in records view' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: "\e[C", key: double('Key', name: :right)),
      double('Event', value: "\e[C", key: double('Key', name: :right)),
      double('Event', value: "\e[D", key: double('Key', name: :left)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    # 3つのカラムを持つレコードを返す
    allow(client).to receive(:list_records).and_return([{ 'col1' => 1, 'col2' => 2, 'col3' => 3 }])

    RubyMysqlTui.run_main_loop(client)

    # columns_offset が 0 -> 1 -> 2 -> 1 と変化したことを検証
    offsets = states.filter_map { |s| s[:columns_offset] }
    expect(offsets).to include(0, 1, 2)
    expect(offsets.last).to eq(1)
  end
end

RSpec.describe 'E2E Record Deletion - Cancellation' do
  include_context 'e2e setup'

  it 'shows cancellation message when deletion is cancelled' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'd', key: double('Key', name: :d)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:yes?).and_return(false)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:status_message] == 'Deletion cancelled' }).to be true
  end
end

RSpec.describe 'E2E Record Deletion - Success' do
  include_context 'e2e setup'

  it 'shows success message when record is deleted' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'd', key: double('Key', name: :d)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:yes?).and_return(true)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')
    expect(client).to receive(:delete_record).and_return(true)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:status_message] == 'Record deleted successfully' }).to be true
  end
end

RSpec.describe 'E2E Record Edit - No Primary Key' do
  include_context 'e2e setup'

  it 'warns and refuses edit when table has no primary key' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'e', key: double('Key', name: :e)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    expect(prompt).to receive(:say).with('このテーブルには主キーが設定されていないため、レコードを特定して更新することができず、編集は不可能です', color: :yellow)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['no_pk_table'])
    allow(client).to receive(:list_records).and_return([{ 'col1' => 'val1' }])
    allow(client).to receive(:primary_key_for).with('no_pk_table').and_return(nil)

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

RSpec.describe 'E2E Record Deletion - Error' do
  include_context 'e2e setup'

  it 'shows error message when record deletion fails' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'd', key: double('Key', name: :d)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:yes?).and_return(true)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')

    error_msg = 'Internal Server Error'
    expect(client).to receive(:delete_record).and_raise(Mysql2::Error.new(error_msg))

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:status_message] == "Failed to delete record: #{error_msg}" }).to be true
  end
end

RSpec.describe 'E2E Table Creation - Empty Name' do
  include_context 'e2e setup'

  it 'does not create a table when an empty name is provided' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: 'n', key: double('Key', name: :n)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('  ')

    expect(client).not_to receive(:create_table)

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['existing_table'])

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :tables }).to be true
  end
end

RSpec.describe 'E2E Table Creation - Error' do
  include_context 'e2e setup'

  it 'handles error when creating a table with an invalid name' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: 'n', key: double('Key', name: :n)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('invalid_table', '')
    expect(prompt).to receive(:error).with(/エラーが発生しました: Table creation failed/)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['existing_table'])
    error = Mysql2::Error.new('Table creation failed')
    expect(client).to receive(:create_table).with('invalid_table', []).and_raise(error)

    expect(RubyMysqlTui.logger).to receive(:error).with(/Table Creation Error: Table creation failed/)

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :tables }).to be true
  end
end

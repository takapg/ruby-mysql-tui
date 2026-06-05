# frozen_string_literal: true

RSpec.describe 'E2E Record Clone' do
  include_context 'e2e setup'

  it 'clones a record when c is pressed' do
    allow(TTY::Reader).to receive(:new).and_return(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'c', key: double('Key', name: :c)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)

    prompt = instance_double(TTY::Prompt)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:ask).and_return('2', 'Alice')

    states = track_states(client)
    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['test_table'])
    allow(client).to receive(:list_records).and_return([{ 'id' => 1, 'name' => 'Alice' }])
    allow(client).to receive(:primary_key_for).and_return('id')
    allow(client).to receive(:list_columns).and_return(['id', 'name'])
    allow(client).to receive(:list_table_structure).and_return([])

    expect(client).to receive(:insert_record).with('test_table', { 'id' => '2', 'name' => 'Alice' })

    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :records }).to be true
  end
end

require 'spec_helper'
require_relative 'e2e_helper'
require 'ruby_mysql_tui'

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

  def retry_events
    [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'n', key: double('Key', name: :n)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
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

  def setup_edit_events(reader)
    events = [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'e', key: double('Key', name: :e)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
    allow(reader).to receive(:read_keypress).and_return(*events)
  end

  def setup_edit_prompt_mocks(prompt)
    allow(prompt).to receive(:select).and_return('name')
    allow(prompt).to receive(:ask).and_return('duplicate_id', 'valid_id')
    allow(prompt).to receive(:say)
  end

  def all_records_events
    [
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\r", key: double('Key', name: :return)),
      double('Event', value: "\t", key: double('Key', name: :tab)),
      double('Event', value: 'a', key: double('Key', name: :a)),
      double('Event', value: 'a', key: double('Key', name: :a)),
      double('Event', value: 'q', key: double('Key', name: :q))
    ]
  end
end

RSpec.shared_context 'e2e setup' do
  include E2EFlowHelpers

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
    allow(client).to receive(:list_records).with('test_table', 0).and_return([{ 'id' => 1 }])

    all_records = [{ 'id' => 1 }, { 'id' => 2 }, { 'id' => 3 }]
    expect(client).to receive(:list_records).with('test_table', 0, limit: RubyMysqlTui::Client::MAX_RECORDS_LIMIT).and_return(all_records)
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
    allow(prompt).to receive(:ask).and_return('new_e2e_table')

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(%w[existing_table new_e2e_table])
    expect(client).to receive(:create_table).with('new_e2e_table')

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
      double('Event', value: 'q', key: double('Key', name: :q))        # Quit
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

    offsets = states.filter_map { |s| s[:detail_offset] }
    expect(offsets).to include(0, 1, 2)
    expect(offsets.last).to eq(2)
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
    allow(prompt).to receive(:ask).and_return('invalid_table')
    expect(prompt).to receive(:error).with(/エラーが発生しました: Table creation failed/)

    allow(client).to receive(:list_databases).and_return([E2EHelper::TEST_DB])
    allow(client).to receive(:list_tables).and_return(['existing_table'])
    error = Mysql2::Error.new('Table creation failed')
    expect(client).to receive(:create_table).with('invalid_table').and_raise(error)

    expect(RubyMysqlTui.logger).to receive(:error).with(/Table Creation Error: Table creation failed/)

    states = track_states(client)
    RubyMysqlTui.run_main_loop(client)
    expect(states.any? { |s| s[:view_mode] == :tables }).to be true
  end
end

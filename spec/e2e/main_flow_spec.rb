# frozen_string_literal: true

require 'spec_helper'
require_relative 'e2e_helper'
require 'ruby_mysql_tui'

RSpec.shared_context 'e2e setup' do
  before(:all) { E2EHelper.setup_test_db }
  after(:all) { E2EHelper.cleanup_test_db }
  let(:client) { RubyMysqlTui::Client.new(host: ENV.fetch('MYSQL_HOST', '127.0.0.1'), database: E2EHelper::TEST_DB) }
  let(:reader) { instance_double(TTY::Reader) }

  def track_states(client)
    states = [RubyMysqlTui.initial_state(client).dup]
    allow(RubyMysqlTui).to receive(:handle_input).and_wrap_original do |m, *args|
      res = m.call(*args)
      states << res.dup if res.is_a?(Hash)
      res
    end
    states
  end
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
    expect(states.last[:focus]).not_to eq(initial_focus)
  end
end

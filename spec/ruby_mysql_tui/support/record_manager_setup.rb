# frozen_string_literal: true

RSpec.shared_context 'record manager setup' do
  let(:client) { instance_double('RubyMysqlTui::Client') }
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:table_name) { 'users' }
  let(:pk_column) { 'id' }
  let(:record) { { 'id' => 1, 'name' => 'Alice' } }
  let(:state) do
    {
      focus: :right,
      view_mode: :records,
      selected_table: table_name,
      selected_record_index: 0,
      records: [record],
      records_offset: 0
    }
  end
end

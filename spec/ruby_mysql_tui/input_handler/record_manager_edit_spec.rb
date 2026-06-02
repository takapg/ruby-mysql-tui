# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/record_manager'

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

RSpec.describe RubyMysqlTui::InputHandler::RecordManager do
  describe '.handle_edit_record execution' do
    include_context 'record manager setup'
    before do
      allow(client).to receive(:primary_key_for).with(table_name).and_return(pk_column)
    end

    it 'updates the record when valid column and value are provided' do
      expect(prompt).to receive(:select).with('編集するカラムを選択してください:', record.keys).and_return('name')
      expect(prompt).to receive(:ask).with('新しい値を入力してください (name):').and_return('Bob')
      expect(client).to receive(:update_record).with(table_name, pk_column, 1, 'name', 'Bob')
      expect(client).to receive(:list_records).with(table_name, 0).and_return([{ 'id' => 1, 'name' => 'Bob' }])

      result_state = described_class.handle_edit_record(state, client, prompt)
      expect(result_state[:records]).to eq([{ 'id' => 1, 'name' => 'Bob' }])
    end

    it 'does not update when value is nil' do
      expect(prompt).to receive(:select).and_return('name')
      expect(prompt).to receive(:ask).and_return(nil)
      expect(client).not_to receive(:update_record)

      described_class.handle_edit_record(state, client, prompt)
    end

    it 'handles Mysql2::Error during update' do
      allow(prompt).to receive(:select).and_return('name')
      allow(prompt).to receive(:ask).and_return('Bob')
      allow(client).to receive(:update_record).and_raise(Mysql2::Error, 'Update failed')
      expect(RubyMysqlTui.logger).to receive(:error).with(/Failed to update record: Update failed/)
      expect(prompt).to receive(:say).with(/更新に失敗しました: Update failed/, color: :red)

      described_class.handle_edit_record(state, client, prompt)
    end
  end
end

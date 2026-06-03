# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/input_handler/record_prompt'

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.get_editable_columns' do
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:record) { { 'id' => 1, 'name' => 'Alice', 'email' => 'alice@example.com' } }
  let(:pk_column) { 'id' }

  it 'excludes the primary key column' do
    cols = described_class.get_editable_columns(record, prompt, pk_column)
    expect(cols).to eq(%w[name email])
    expect(cols).not_to include(pk_column)
  end

  it 'returns nil and warns when pk_column is nil' do
    expect(prompt).to receive(:say).with('主キーが設定されていないため、編集できません', color: :yellow)
    cols = described_class.get_editable_columns(record, prompt, nil)
    expect(cols).to be_nil
  end

  it 'returns nil and warns when no editable columns exist' do
    record_only_pk = { 'id' => 1 }
    expect(prompt).to receive(:say).with('編集可能なカラムがありません', color: :yellow)
    cols = described_class.get_editable_columns(record_only_pk, prompt, pk_column)
    expect(cols).to be_nil
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.warn_pk_not_editable' do
  let(:prompt) { instance_double('TTY::Prompt') }

  it 'shows a red warning message' do
    expect(prompt).to receive(:say).with('主キーは編集できません', color: :red)
    described_class.warn_pk_not_editable(prompt)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.required_column?' do
  let(:structure) do
    [
      { 'Field' => 'id', 'Null' => 'NO' },
      { 'Field' => 'name', 'Null' => 'NO' },
      { 'Field' => 'email', 'Null' => 'YES' }
    ]
  end

  it 'returns true for NOT NULL columns' do
    expect(described_class.required_column?('id', structure)).to be true
    expect(described_class.required_column?('name', structure)).to be true
  end

  it 'returns false for nullable columns' do
    expect(described_class.required_column?('email', structure)).to be false
  end

  it 'returns false for non-existent columns' do
    expect(described_class.required_column?('unknown', structure)).to be false
  end
end

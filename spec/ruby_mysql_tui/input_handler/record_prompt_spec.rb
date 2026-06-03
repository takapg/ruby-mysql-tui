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

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.type_validation_for numeric' do
  let(:structure) do
    [
      { 'Field' => 'age', 'Type' => 'int(11)' },
      { 'Field' => 'price', 'Type' => 'decimal(10,2)' },
      { 'Field' => 'weight', 'Type' => 'float' }
    ]
  end

  it 'returns integer validation for int type' do
    regex, msg = described_class.type_validation_for('age', structure)
    expect(regex).to eq(/\A-?\d+\z/)
    expect(regex).to match('123')
    expect(regex).to match('-123')
    expect(regex).not_to match('12.3')
    expect(regex).not_to match('abc')
    expect(msg).to eq('数値のみ入力してください')
  end

  it 'returns numeric validation for decimal/float type' do
    regex, msg = described_class.type_validation_for('price', structure)
    expect(regex).to eq(/\A-?\d+(\.\d+)?\z/)
    expect(regex).to match('123')
    expect(regex).to match('123.45')
    expect(regex).to match('-123.45')
    expect(regex).not_to match('abc')
    expect(msg).to eq('数値を入力してください')

    regex, = described_class.type_validation_for('weight', structure)
    expect(regex).to eq(/\A-?\d+(\.\d+)?\z/)
    expect(regex).to match('123.45')
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.type_validation_for date/datetime' do
  it 'returns date/datetime validation for date types' do
    date_structure = [
      { 'Field' => 'created_at', 'Type' => 'datetime' },
      { 'Field' => 'birthday', 'Type' => 'date' },
      { 'Field' => 'updated_at', 'Type' => 'timestamp' }
    ]

    regex, msg = described_class.type_validation_for('birthday', date_structure)
    expect(regex).to eq(/\A\d{4}-\d{2}-\d{2}\z/)
    expect(regex).to match('2023-01-01')
    expect(regex).not_to match('2023-1-1')
    expect(regex).not_to match('abc')
    expect(msg).to eq('日付形式 (YYYY-MM-DD) で入力してください')

    regex, msg = described_class.type_validation_for('created_at', date_structure)
    expect(regex).to eq(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/)
    expect(regex).to match('2023-01-01 12:00:00')
    expect(regex).not_to match('2023-01-01 12:00')
    expect(regex).not_to match('abc')
    expect(msg).to eq('日時形式 (YYYY-MM-DD HH:MM:SS) で入力してください')

    regex, = described_class.type_validation_for('updated_at', date_structure)
    expect(regex).to eq(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/)
    expect(regex).to match('2023-01-01 12:00:00')
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.type_validation_for non-numeric' do
  let(:structure) { [{ 'Field' => 'name', 'Type' => 'varchar(255)' }] }

  it 'returns nil for varchar type' do
    expect(described_class.type_validation_for('name', structure)).to be_nil
  end

  it 'returns nil for non-existent column' do
    expect(described_class.type_validation_for('unknown', structure)).to be_nil
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

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.prompt_for_record_data NOT NULL' do
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:columns) { %w[name email] }
  let(:structure) do
    [
      { 'Field' => 'name', 'Null' => 'NO' },
      { 'Field' => 'email', 'Null' => 'YES' }
    ]
  end

  it 'applies validation only to NOT NULL columns' do
    question_name = instance_double('TTY::Prompt::Question')
    question_email = instance_double('TTY::Prompt::Question')

    expect(prompt).to receive(:ask).with(/name/, any_args).and_yield(question_name).and_return('Alice')
    expect(prompt).to receive(:ask).with(/email/, any_args).and_yield(question_email).and_return('alice@example.com')

    expect(question_name).to receive(:required).with(true)
    expect(question_name).to receive(:validate).with(/\S+/, '入力してください')
    expect(question_email).not_to receive(:required)
    expect(question_email).not_to receive(:validate)

    described_class.prompt_for_record_data(columns, prompt, {}, structure)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.prompt_for_record_data type' do
  let(:prompt) { instance_double('TTY::Prompt') }

  it 'applies type validation for numeric columns' do
    columns = %w[age]
    structure = [{ 'Field' => 'age', 'Type' => 'int(11)', 'Null' => 'NO' }]
    question = instance_double('TTY::Prompt::Question')

    expect(prompt).to receive(:ask).with(/age/, any_args).and_yield(question).and_return('25')
    expect(question).to receive(:required).with(true)
    expect(question).to receive(:validate).with(/\S+/, '入力してください')
    expect(question).to receive(:validate).with(/\A-?\d+\z/, '数値のみ入力してください')

    described_class.prompt_for_record_data(columns, prompt, {}, structure)
  end

  it 'allows empty input for nullable numeric columns' do
    columns = %w[age]
    structure = [{ 'Field' => 'age', 'Type' => 'int(11)', 'Null' => 'YES' }]
    question = instance_double('TTY::Prompt::Question')

    expect(prompt).to receive(:ask).with(/age/, any_args).and_yield(question).and_return('')
    expect(question).to receive(:validate).with(
      Regexp.union(/\A-?\d+\z/, /\A\s*\z/),
      '数値のみ入力してください'
    )

    described_class.prompt_for_record_data(columns, prompt, {}, structure)
  end
end

RSpec.describe RubyMysqlTui::InputHandler::RecordPrompt, '.prompt_for_edit validation' do
  let(:prompt) { instance_double('TTY::Prompt') }
  let(:record) { { 'id' => 1, 'name' => 'Alice', 'email' => 'alice@example.com' } }
  let(:pk_column) { 'id' }
  let(:structure) do
    [
      { 'Field' => 'name', 'Null' => 'NO' },
      { 'Field' => 'email', 'Null' => 'YES' }
    ]
  end

  it 'applies required and validation for NOT NULL columns' do
    question = instance_double('TTY::Prompt::Question')
    expect(prompt).to receive(:select).and_return('name')
    expect(prompt).to receive(:ask).with(/name/, any_args).and_yield(question).and_return('Bob')

    expect(question).to receive(:required).with(true)
    expect(question).to receive(:validate).with(/\S+/, '入力してください')

    described_class.prompt_for_edit(record, prompt, pk_column, structure)
  end

  it 'does not apply required or validation for nullable columns' do
    question = instance_double('TTY::Prompt::Question')
    expect(prompt).to receive(:select).and_return('email')
    expect(prompt).to receive(:ask).with(/email/, any_args).and_yield(question).and_return('bob@example.com')

    expect(question).not_to receive(:required)
    expect(question).not_to receive(:validate)

    described_class.prompt_for_edit(record, prompt, pk_column, structure)
  end
end

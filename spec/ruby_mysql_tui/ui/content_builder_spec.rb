# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/ruby_mysql_tui/ui/content_builder'

RSpec.describe RubyMysqlTui::UI::ContentBuilder, 'basic' do
  describe '.build_list_text - basic' do
    let(:width) { 20 }
    let(:height) { 10 }

    context 'when items are empty' do
      it 'returns "No items found"' do
        expect(described_class.build_list_text([], 0, width, height)).to eq('No items found')
        expect(described_class.build_list_text(nil, 0, width, height)).to eq('No items found')
      end
    end

    context 'when items fit within height' do
      let(:items) { %w[item1 item2 item3] }

      it 'displays all items' do
        output = described_class.build_list_text(items, 1, width, height)
        expect(output).to include('  item1')
        expect(output).to include('> item2')
        expect(output).to include('  item3')
        expect(output.count("\n")).to eq(2)
      end
    end
  end
end

RSpec.describe RubyMysqlTui::UI::ContentBuilder, 'scrolling edges' do
  let(:width) { 20 }
  let(:height) { 10 }
  let(:items) { (1..20).map { |i| "item#{i}" } }

  it 'slices items and shows the first few when selected_index is 0' do
    output = described_class.build_list_text(items, 0, width, height)
    expect(output).to include('> item1')
    expect(output).to include('  item8')
    expect(output).not_to include('item9')
    expect(output.count("\n")).to eq(7)
  end

  it 'slices items and shows the last few when selected_index is at the end' do
    output = described_class.build_list_text(items, 19, width, height)
    expect(output).to include('  item13')
    expect(output).to include('> item20')
    expect(output).not_to include('item12')
    expect(output.count("\n")).to eq(7)
  end
end

RSpec.describe RubyMysqlTui::UI::RecordsContentBuilder, 'column slicing' do
  let(:width) { 100 }
  let(:height) { 20 }
  let(:records) { [{ 'col1' => 'v1', 'col2' => 'v2', 'col3' => 'v3' }] }

  it 'shows all columns when columns_offset is 0' do
    output = described_class.build_records_text(
      table_name: 'test', records: records, width: width,
      options: { height: height, selected_index: 0, offset: 0, columns_offset: 0 }
    )
    expect(output).to include('col1', 'col2', 'col3')
  end

  it 'slices columns when columns_offset is positive' do
    output1 = described_class.build_records_text(
      table_name: 'test', records: records, width: width,
      options: { height: height, selected_index: 0, offset: 0, columns_offset: 1 }
    )
    expect(output1).not_to include('col1')
    expect(output1).to include('col2', 'col3')

    output2 = described_class.build_records_text(
      table_name: 'test', records: records, width: width,
      options: { height: height, selected_index: 0, offset: 0, columns_offset: 2 }
    )
    expect(output2).not_to include('col1', 'col2')
    expect(output2).to include('col3')
  end
end

RSpec.describe RubyMysqlTui::UI::ContentBuilder, 'scrolling middle' do
  let(:width) { 20 }
  let(:height) { 10 }
  let(:items) { (1..20).map { |i| "item#{i}" } }

  it 'centers the selected_index when it is in the middle' do
    output = described_class.build_list_text(items, 10, width, height)
    expect(output).to include('  item7')
    expect(output).to include('> item11')
    expect(output).to include('  item14')
    expect(output).not_to include('item6')
    expect(output).not_to include('item15')
    expect(output.count("\n")).to eq(7)
  end
end

RSpec.describe RubyMysqlTui::UI::ContentBuilder, 'record detail scrolling' do
  let(:width) { 40 }
  let(:height) { 5 } # max_rows = 3
  let(:record) { { 'col1' => 'v1', 'col2' => 'v2', 'col3' => 'v3', 'col4' => 'v4', 'col5' => 'v5' } }
  let(:state) { { records: [record], selected_record_index: 0, detail_offset: 0 } }

  it 'shows first few columns when offset is 0' do
    output = described_class.build_record_detail_text(state, width, height)
    expect(output).to include('col1: v1')
    expect(output).to include('col2: v2')
    expect(output).to include('col3: v3')
    expect(output).not_to include('col4: v4')
  end

  it 'shows shifted columns when offset is 2' do
    state[:detail_offset] = 2
    output = described_class.build_record_detail_text(state, width, height)
    expect(output).not_to include('col1: v1')
    expect(output).to include('col3: v3')
    expect(output).to include('col4: v4')
    expect(output).to include('col5: v5')
  end
end

RSpec.describe RubyMysqlTui::UI::ContentBuilder, 'record detail NULL' do
  let(:width) { 40 }
  let(:height) { 5 }

  it 'shows "NULL" when value is nil' do
    record = { 'col1' => nil, 'col2' => 'v2' }
    state = { records: [record], selected_record_index: 0, detail_offset: 0 }
    output = described_class.build_record_detail_text(state, width, height)
    expect(output).to include('col1: NULL')
    expect(output).to include('col2: v2')
  end
end

RSpec.describe RubyMysqlTui::UI::ContentBuilder, '.filtered_items basic' do
  let(:items) { %w[Database_A Database_B Test_DB Production_DB] }

  it 'filter_query が nil の場合は全件返すこと' do
    state = { items: items, filter_query: nil }
    expect(described_class.filtered_items(state)).to eq(items)
  end

  it 'filter_query が空文字の場合は全件返すこと' do
    state = { items: items, filter_query: '' }
    expect(described_class.filtered_items(state)).to eq(items)
  end

  it 'キーワードに一致するアイテムのみを返すこと' do
    state = { items: items, filter_query: 'Database' }
    expect(described_class.filtered_items(state)).to eq(%w[Database_A Database_B])
  end
end

RSpec.describe RubyMysqlTui::UI::ContentBuilder, '.filtered_items edge cases' do
  let(:items) { %w[Database_A Database_B Test_DB Production_DB] }

  it '大文字小文字を区別せずにフィルタリングすること' do
    state = { items: items, filter_query: 'db' }
    expect(described_class.filtered_items(state)).to eq(%w[Test_DB Production_DB])
  end

  it '一致するアイテムがない場合は空配列を返すこと' do
    state = { items: items, filter_query: 'NonExistent' }
    expect(described_class.filtered_items(state)).to eq([])
  end

  it 'items が nil の場合は空配列を返すこと' do
    state = { items: nil, filter_query: 'db' }
    expect(described_class.filtered_items(state)).to eq([])
  end
end

RSpec.describe RubyMysqlTui::UI::RecordsContentBuilder, 'filtering basic' do
  let(:width) { 100 }
  let(:height) { 20 }
  let(:records) do
    [
      { 'id' => 1, 'name' => 'Alice' },
      { 'id' => 2, 'name' => 'Bob' },
      { 'id' => 3, 'name' => 'Charlie' }
    ]
  end

  it 'filter_query が空のときは全件表示すること' do
    state = { records: records, records_filter_query: '', selected_table: 'test' }
    output = described_class.build_view(state, width, height)
    expect(output).to include('Alice', 'Bob', 'Charlie')
  end

  it 'キーワードに一致するレコードのみを表示すること (大文字小文字区別なし)' do
    state = { records: records, records_filter_query: 'al', selected_table: 'test' }
    output = described_class.build_view(state, width, height)
    expect(output).to include('Alice')
    expect(output).not_to include('Bob', 'Charlie')
  end

  it '一致するレコードが 0 件の場合、「No records found」と表示すること' do
    state = { records: records, records_filter_query: 'nonexistent', selected_table: 'test' }
    output = described_class.build_view(state, width, height)
    expect(output).to include('No records found')
  end
end

RSpec.describe RubyMysqlTui::UI::RecordsContentBuilder, 'filtering advanced - column search' do
  let(:width) { 100 }
  let(:height) { 20 }

  it 'いずれかのカラムにキーワードが含まれていれば表示すること' do
    records_with_id = [
      { 'id' => '101', 'name' => 'Alice' },
      { 'id' => '102', 'name' => 'Bob' }
    ]
    state = { records: records_with_id, records_filter_query: '102', selected_table: 'test' }
    output = described_class.build_view(state, width, height)
    expect(output).to include('Bob')
    expect(output).not_to include('Alice')
  end
end

RSpec.describe RubyMysqlTui::UI::RecordsContentBuilder, 'filtering advanced - clamp' do
  let(:width) { 100 }
  let(:height) { 20 }
  let(:records) do
    [
      { 'id' => 1, 'name' => 'Alice' },
      { 'id' => 2, 'name' => 'Bob' },
      { 'id' => 3, 'name' => 'Charlie' }
    ]
  end

  it 'フィルタリング後に selected_record_index が範囲外にならないよう clamp されること' do
    state = {
      records: records,
      records_filter_query: 'Alice',
      selected_table: 'test',
      selected_record_index: 2
    }
    output = described_class.build_view(state, width, height)
    expect(output).to include('> 1 Alice')
  end

  it 'shows "NULL" when record value is nil' do
    records = [{ 'id' => 1, 'name' => nil }]
    state = { records: records, selected_table: 'test' }
    output = described_class.build_view(state, width, height)
    expect(output).to include('NULL')
  end
end

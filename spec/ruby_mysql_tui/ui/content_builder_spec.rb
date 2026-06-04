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

RSpec.describe RubyMysqlTui::UI::ContentBuilder, 'column slicing' do
  let(:width) { 100 }
  let(:height) { 20 }
  let(:records) { [{ 'col1' => 'v1', 'col2' => 'v2', 'col3' => 'v3' }] }

  it 'slices columns based on columns_offset' do
    # offset 0: col1, col2, col3 が表示される
    output0 = described_class.build_records_text(
      table_name: 'test', records: records, width: width,
      options: { height: height, selected_index: 0, offset: 0, columns_offset: 0 }
    )
    expect(output0).to include('col1')
    expect(output0).to include('col2')
    expect(output0).to include('col3')

    # offset 1: col2, col3 が表示される
    output1 = described_class.build_records_text(
      table_name: 'test', records: records, width: width,
      options: { height: height, selected_index: 0, offset: 0, columns_offset: 1 }
    )
    expect(output1).not_to include('col1')
    expect(output1).to include('col2')
    expect(output1).to include('col3')

    # offset 2: col3 のみが表示される
    output2 = described_class.build_records_text(
      table_name: 'test', records: records, width: width,
      options: { height: height, selected_index: 0, offset: 0, columns_offset: 2 }
    )
    expect(output2).not_to include('col1')
    expect(output2).not_to include('col2')
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

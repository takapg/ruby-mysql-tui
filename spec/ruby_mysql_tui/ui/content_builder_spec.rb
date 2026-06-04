# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/ruby_mysql_tui/ui/content_builder'

RSpec.describe RubyMysqlTui::UI::ContentBuilder do
  describe '.build_list_text' do
    let(:width) { 20 }
    let(:height) { 10 } # max_rows = 8

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

    context 'when items exceed height' do
      let(:items) { (1..20).map { |i| "item#{i}" } }

      it 'slices items and shows the first few when selected_index is 0' do
        output = described_class.build_list_text(items, 0, width, height)
        expect(output).to include('> item1')
        expect(output).to include('  item8')
        expect(output).not_to include('item9')
        expect(output.count("\n")).to eq(7) # max_rows - 1
      end

      it 'slices items and shows the last few when selected_index is at the end' do
        output = described_class.build_list_text(items, 19, width, height)
        expect(output).to include('  item13')
        expect(output).to include('> item20')
        expect(output).not_to include('item12')
        expect(output.count("\n")).to eq(7)
      end

      it 'centers the selected_index when it is in the middle' do
        # max_rows = 8, selected = 10. start_idx = (10 - 4).clamp(0, 12) = 6
        # visible: items[6..13] (item7..item14)
        output = described_class.build_list_text(items, 10, width, height)
        expect(output).to include('  item7')
        expect(output).to include('> item11')
        expect(output).to include('  item14')
        expect(output).not_to include('item6')
        expect(output).not_to include('item15')
        expect(output.count("\n")).to eq(7)
      end
    end
  end
end

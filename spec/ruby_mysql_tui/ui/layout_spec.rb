# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mysql_tui/ui/layout'

RSpec.describe RubyMysqlTui::UI::Layout do
  let(:layout) { described_class.new }

  describe '#update_dimensions' do
    it 'calculates dimensions correctly for a standard terminal size' do
      allow(TTY::Screen).to receive(:width).and_return(100)
      allow(TTY::Screen).to receive(:height).and_return(30)

      layout.update_dimensions

      expect(layout.width).to eq(100)
      expect(layout.height).to eq(30)
      expect(layout.header_h).to eq(3)
      expect(layout.footer_h).to eq(3)
      expect(layout.log_h).to eq(5)
      expect(layout.main_h).to eq(30 - 3 - 3 - 5)
      expect(layout.left_w).to eq((100 * 0.3).to_i)
      expect(layout.right_w).to eq(100 - (100 * 0.3).to_i - 1)
    end

    it 'ensures main_h is at least 1 even for very small terminal heights' do
      allow(TTY::Screen).to receive(:width).and_return(80)
      allow(TTY::Screen).to receive(:height).and_return(5) # 非常に低い高さ

      layout.update_dimensions

      expect(layout.main_h).to be >= 1
    end
  end
end

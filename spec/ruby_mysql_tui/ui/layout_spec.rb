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
      expect([layout.width, layout.height, layout.main_h, layout.left_w, layout.right_w]).to eq([100, 30, 19, 30, 69])
    end

    it 'ensures main_h is at least 1 for small heights' do
      allow(TTY::Screen).to receive(:height).and_return(5)
      layout.update_dimensions
      expect(layout.main_h).to be >= 1
    end

    it 'ensures minimum width for narrow terminals' do
      allow(TTY::Screen).to receive(:width).and_return(5)
      layout.update_dimensions
      expect(layout.left_w).to be >= 10
      expect(layout.right_w).to be >= 1
    end
  end
end

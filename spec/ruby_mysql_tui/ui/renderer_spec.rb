# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require_relative '../../../lib/ruby_mysql_tui/ui/renderer'
require_relative '../../../lib/ruby_mysql_tui/ui/layout'

RSpec.describe RubyMysqlTui::UI::Renderer do
  let(:layout) { RubyMysqlTui::UI::Layout.new }
  let(:renderer) { described_class.new(layout) }
  let(:client) { double('Client', config: { host: 'localhost', username: 'root', database: 'test' }) }

  before do
    allow(TTY::Screen).to receive(:width).and_return(100)
    allow(TTY::Screen).to receive(:height).and_return(30)
  end

  describe '#render' do
    it 'renders different output based on focus state' do
      left_output = StringIO.new
      right_output = StringIO.new

      original_stdout = $stdout

      $stdout = left_output
      renderer.render(client, :left)
      $stdout = original_stdout

      $stdout = right_output
      renderer.render(client, :right)
      $stdout = original_stdout

      expect(left_output.string).not_to eq(right_output.string)
    end
  end
end

# frozen_string_literal: true

require 'stringio'
require 'spec_helper'
require_relative '../../../lib/ruby_mysql_tui/ui/renderer'
require_relative '../../../lib/ruby_mysql_tui/ui/layout'

RSpec.shared_context 'renderer setup' do
  let(:layout) { RubyMysqlTui::UI::Layout.new }
  let(:renderer) { described_class.new(layout) }
  let(:client) { double('Client', config: { host: 'localhost', username: 'root', database: 'test' }) }

  before do
    allow(TTY::Screen).to receive(:width).and_return(100)
    allow(TTY::Screen).to receive(:height).and_return(30)

    # TTY::Box.frame をモックして、色情報を文字列に含めることで検証可能にする
    allow(TTY::Box).to receive(:frame) do |args, &block|
      color = args[:style] ? args[:style][:border][:fg] : :none
      content = block&.call
      "Box(color: #{color}, content: #{content})"
    end
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'focus' do
  include_context 'renderer setup'
  describe '#render' do
    it 'applies correct colors based on focus' do
      %i[left right].each do |focus|
        state = { focus: focus, items: %w[db1 db2], selected_index: 0, view_mode: :databases, selected_db: nil }
        c, o = focus == :left ? %w[cyan white] : %w[white cyan]
        expect { renderer.render(client, state) }.to output(/Box\(color: #{c}, content: > db1/).to_stdout
        expect { renderer.render(client, state) }.to output(
          /Box\(color: #{o}, content: Data will appear here\)/
        ).to_stdout
      end
    end
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'content' do
  include_context 'renderer setup'
  describe '#render' do
    context 'when view_mode is :databases' do
      it 'displays "No items found" when the database list is empty' do
        state = { focus: :left, items: [], selected_index: 0, view_mode: :databases, selected_db: nil }
        expect { renderer.render(client, state) }.to output(/Box\(color: cyan, content: No items found\)/).to_stdout
      end
    end

    context 'when view_mode is :tables' do
      it 'displays table list in the right pane' do
        state = { focus: :left, items: %w[table1 table2], selected_index: 0, view_mode: :tables, selected_db: 'test_db' }
        output = capture_stdout { renderer.render(client, state) }
        expect(output).to include('Box(color: white, content: Database: test_db')
        expect(output).to include('table1')
        expect(output).to include('table2')
      end

      it 'displays "No tables found" when items are empty' do
        state = { focus: :left, items: [], selected_index: 0, view_mode: :tables, selected_db: 'test_db' }
        output = capture_stdout { renderer.render(client, state) }
        expect(output).to include('Box(color: white, content: Database: test_db')
        expect(output).to include('No tables found')
      end

      it 'truncates long table names' do
        long_table = 'a' * 100
        state = { focus: :left, items: [long_table], selected_index: 0, view_mode: :tables, selected_db: 'test_db' }
        output = capture_stdout { renderer.render(client, state) }
        expect(output).to include('...')
        expect(output).not_to include(long_table)
      end
    end
  end
end

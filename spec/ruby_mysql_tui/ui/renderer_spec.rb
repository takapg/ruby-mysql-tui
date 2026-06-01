# frozen_string_literal: true

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
end

RSpec.describe RubyMysqlTui::UI::Renderer do
  include_context 'renderer setup'

  describe '#render' do
    it 'applies cyan color to the focused pane and displays databases' do
      databases = %w[db1 db2]
      # 左ペインフォーカス時: 左がcyan、右がwhite
      state_left = { focus: :left, items: databases, selected_index: 0, view_mode: :databases, selected_db: nil }
      expect { renderer.render(client, state_left) }
        .to output(/Box\(color: cyan, content: > db1/).to_stdout
      expect { renderer.render(client, state_left) }
        .to output(/db2\)/).to_stdout
      expect { renderer.render(client, state_left) }
        .to output(/Box\(color: white, content: Data will appear here\)/).to_stdout

      # 右ペインフォーカス時: 左がwhite、右がcyan
      state_right = { focus: :right, items: databases, selected_index: 0, view_mode: :databases, selected_db: nil }
      expect { renderer.render(client, state_right) }
        .to output(/Box\(color: white, content: > db1/).to_stdout
      expect { renderer.render(client, state_right) }
        .to output(/db2\)/).to_stdout
      expect { renderer.render(client, state_right) }
        .to output(/Box\(color: cyan, content: Data will appear here\)/).to_stdout
    end

    it 'displays "No items found" when the database list is empty' do
      databases = []
      state = { focus: :left, items: databases, selected_index: 0, view_mode: :databases, selected_db: nil }
      expect { renderer.render(client, state) }
        .to output(/Box\(color: cyan, content: No items found\)/).to_stdout
    end
  end
end

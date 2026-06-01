# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/ruby_mysql_tui/ui/renderer'
require_relative '../../../lib/ruby_mysql_tui/ui/layout'

RSpec.describe RubyMysqlTui::UI::Renderer do
  let(:layout) { RubyMysqlTui::UI::Layout.new }
  let(:renderer) { described_class.new(layout) }
  let(:client) { double('Client', config: { host: 'localhost', username: 'root', database: 'test' }) }

  describe '#render' do
    it 'accepts focus state and renders without error' do
      expect { renderer.render(client, :left) }.not_to raise_error
      expect { renderer.render(client, :right) }.not_to raise_error
    end
  end
end

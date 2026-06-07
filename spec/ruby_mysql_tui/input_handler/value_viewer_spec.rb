# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/ruby_mysql_tui/input_handler/value_viewer'

RSpec.describe RubyMysqlTui::InputHandler::ValueViewer do
  describe '.view_value' do
    let(:value) { 'test value' }

    it 'does nothing if value is nil' do
      expect(Tempfile).not_to receive(:create)
      described_class.view_value(nil)
    end

    it 'writes value to a temporary file and opens it with the pager' do
      temp_file = instance_double(Tempfile, path: '/tmp/tui_value.txt')
      allow(Tempfile).to receive(:create).and_yield(temp_file)
      allow(temp_file).to receive(:write)
      allow(temp_file).to receive(:flush)
      allow(temp_file).to receive(:unlink)
      allow(ENV).to receive(:[]).with('PAGER').and_return('less')

      expect(temp_file).to receive(:write).with(value)
      expect(temp_file).to receive(:flush)
      expect(described_class).to receive(:system).with('less /tmp/tui_value.txt')
      expect(temp_file).to receive(:unlink)

      described_class.view_value(value)
    end
  end
end

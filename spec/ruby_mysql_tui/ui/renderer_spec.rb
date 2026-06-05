# frozen_string_literal: true

require 'stringio'
require 'spec_helper'
require_relative '../../../lib/ruby_mysql_tui/ui/renderer'
require_relative '../../../lib/ruby_mysql_tui/ui/layout'

RSpec.shared_context 'renderer setup' do
  let(:layout) { RubyMysqlTui::UI::Layout.new }
  let(:renderer) { described_class.new(layout) }
  let(:client) { double('Client', config: { host: 'localhost', username: 'root', database: 'test' }, last_sql: nil) }

  before do
    allow(TTY::Screen).to receive(:width).and_return(100)
    allow(TTY::Screen).to receive(:height).and_return(30)

    # TTY::Box.frame をモックして、色情報を文字列に含めることで検証可能にする
    allow(TTY::Box).to receive(:frame) do |args, &block|
      color = args[:style] ? args[:style][:border][:fg] : :none
      content = block ? block.call : args[:text]
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

RSpec.describe RubyMysqlTui::UI::Renderer, 'content databases' do
  include_context 'renderer setup'
  describe '#render' do
    context 'when view_mode is :databases' do
      it 'displays "No items found" when the database list is empty' do
        state = { focus: :left, items: [], selected_index: 0, view_mode: :databases, selected_db: nil }
        expect { renderer.render(client, state) }.to output(/Box\(color: cyan, content: No items found\)/).to_stdout
      end
    end
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'content tables - display' do
  include_context 'renderer setup'

  it 'displays table list in the right pane' do
    state = {
      focus: :left, items: %w[table1 table2], selected_index: 0,
      view_mode: :tables, selected_db: 'test_db'
    }
    output = capture_stdout { renderer.render(client, state) }
    expect(output).to include('Box(color: white, content: Database: test_db')
    expect(output).to include('table1')
    expect(output).to include('table2')
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'content tables - edge cases' do
  include_context 'renderer setup'

  it 'displays "No tables found" when items are empty' do
    state = {
      focus: :left, items: [], selected_index: 0,
      view_mode: :tables, selected_db: 'test_db'
    }
    output = capture_stdout { renderer.render(client, state) }
    expect(output).to include('Box(color: white, content: Database: test_db')
    expect(output).to include('No tables found')
  end

  it 'truncates long table names' do
    long_table = 'a' * 100
    state = {
      focus: :left, items: [long_table], selected_index: 0,
      view_mode: :tables, selected_db: 'test_db'
    }
    output = capture_stdout { renderer.render(client, state) }
    expect(output).to include('...')
    expect(output).not_to include(long_table)
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'content records - with data' do
  include_context 'renderer setup'
  describe '#render' do
    it 'displays records in a table format in the right pane' do
      state = {
        focus: :left,
        view_mode: :records,
        selected_table: 'users',
        records: [{ 'id' => 1, 'name' => 'Alice' }, { 'id' => 2, 'name' => 'Bob' }],
        items: []
      }
      output = capture_stdout { renderer.render(client, state) }
      expect(output).to include('Box(color: white, content: Table: users')
      expect(output).to include('1')
      expect(output).to include('Alice')
      expect(output).to include('2')
      expect(output).to include('Bob')
    end
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'log display' do
  include_context 'renderer setup'
  it 'displays the last executed SQL' do
    client = double(
      'Client',
      last_sql: 'SELECT * FROM users',
      config: { host: 'localhost', username: 'root', database: 'test' }
    )
    state = { focus: :left, items: [], selected_index: 0, view_mode: :databases, selected_db: nil }
    expect { renderer.render(client, state) }.to output(/Last SQL: SELECT \* FROM users/).to_stdout
  end

  it 'displays "No SQL executed" when no SQL has been run' do
    client = double('Client', last_sql: nil, config: { host: 'localhost', username: 'root', database: 'test' })
    state = { focus: :left, items: [], selected_index: 0, view_mode: :databases, selected_db: nil }
    expect { renderer.render(client, state) }.to output(/No SQL executed/).to_stdout
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'log truncation' do
  include_context 'renderer setup'
  it 'truncates very long SQL queries' do
    long_sql = "SELECT #{'a' * 200} FROM users"
    client = double(
      'Client',
      last_sql: long_sql,
      config: { host: 'localhost', username: 'root', database: 'test' }
    )
    state = { focus: :left, items: [], selected_index: 0, view_mode: :databases, selected_db: nil }
    output = capture_stdout { renderer.render(client, state) }
    expect(output).to include('...')
    expect(output).not_to include(long_sql)
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'content records - empty' do
  include_context 'renderer setup'
  describe '#render' do
    it 'displays "No records found" when records are empty' do
      state = {
        focus: :left,
        view_mode: :records,
        selected_table: 'users',
        records: [],
        items: []
      }
      output = capture_stdout { renderer.render(client, state) }
      expect(output).to include('Box(color: white, content: Table: users')
      expect(output).to include('No records found')
    end
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'content records - pagination height' do
  include_context 'renderer setup'

  it 'does not exceed the main height when displaying many records' do
    # ターミナルの高さを小さく設定 (main_h が小さくなるように)
    allow(TTY::Screen).to receive(:height).and_return(15)
    layout = RubyMysqlTui::UI::Layout.new
    renderer = described_class.new(layout)

    state = {
      focus: :left,
      view_mode: :records,
      selected_table: 'users',
      records: Array.new(100) { |i| { 'id' => i, 'name' => "User #{i}" } },
      items: []
    }

    output = capture_stdout { renderer.render(client, state) }

    # 右ペインのコンテンツ部分を抽出して行数を確認
    # TTY::Box の出力形式 "Box(color: white, content: ...)" から中身を取り出す
    right_box_match = output.match(/Box\(color: white, content: (.*?)\)\n/m)
    expect(right_box_match).not_to be_nil

    content = right_box_match[1]
    line_count = content.count("\n") + 1
    expect(line_count).to be <= layout.main_h
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'content records - pagination offset' do
  include_context 'renderer setup'

  it 'displays records starting from the offset' do
    state = {
      focus: :left,
      view_mode: :records,
      selected_table: 'users',
      records: [{ 'id' => 1, 'name' => 'Alice' }, { 'id' => 2, 'name' => 'Bob' }, { 'id' => 3, 'name' => 'Charlie' }],
      records_offset: 1,
      items: []
    }

    output = capture_stdout { renderer.render(client, state) }
    expect(output).to include('Bob')
    expect(output).to include('Charlie')
    expect(output).not_to include('Alice')
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'footer guide - basic' do
  include_context 'renderer setup'

  it 'displays left-pane guides when focus is :left' do
    state = { focus: :left, items: [], selected_index: 0, view_mode: :databases, selected_db: nil }
    expect { renderer.render(client, state) }.to output(
      %r{\[q\] Quit \| \[Tab\] Switch Focus \| \[b\] Back \| \[↑/↓\] Move \| \[Enter\] Select}
    ).to_stdout
  end

  it 'excludes record-action guides when focus is :right and view_mode is not :records' do
    state = { focus: :right, items: [], selected_index: 0, view_mode: :tables, selected_db: 'test_db' }
    expect { renderer.render(client, state) }.to output(/\[q\] Quit \| \[Tab\] Switch Focus/).to_stdout
    expect { renderer.render(client, state) }.not_to output(/\[n\] New/).to_stdout
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'footer guide - records' do
  include_context 'renderer setup'

  it 'displays record-action guides when focus is :right and view_mode is :records' do
    state = { focus: :right, items: [], selected_index: 0, view_mode: :records, selected_table: 'users' }
    regex = /\[q\] Quit \| \[Tab\] Switch Focus \| \[n\] New \| \[e\] Edit \| / +
             /\[d\] Delete \| \[c\] Clone \| \[a\] All Records/
    expect { renderer.render(client, state) }.to output(regex).to_stdout
  end

  it 'displays ALL RECORDS MODE prefix and changes [a] label when all_records_mode is true' do
    state = {
      focus: :right, items: [], selected_index: 0, view_mode: :records,
      selected_table: 'users', all_records_mode: true
    }
    expect { renderer.render(client, state) }.to output(/\[ALL RECORDS MODE\] \[q\] Quit.*\[a\] Normal Mode/).to_stdout
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'footer guide - structure' do
  include_context 'renderer setup'

  it 'displays [i] Records and [↑/↓] Move when focus is :right and view_mode is :table_structure' do
    state = { focus: :right, items: [], selected_index: 0, view_mode: :table_structure, selected_table: 'users' }
    expect { renderer.render(client, state) }.to output(%r{\[i\] Records \| \[↑/↓\] Move}).to_stdout
  end
end

RSpec.describe RubyMysqlTui::UI::Renderer, 'content structure - slicing' do
  include_context 'renderer setup'

  it 'slices structure data based on records_offset' do
    state = {
      focus: :right,
      view_mode: :table_structure,
      selected_table: 'users',
      records: [{ 'Field' => 'id' }, { 'Field' => 'name' }, { 'Field' => 'email' }],
      records_offset: 1,
      items: []
    }
    output = capture_stdout { renderer.render(client, state) }
    expect(output).to include('name')
    expect(output).to include('email')
    expect(output).not_to include('id')
  end
end

# frozen_string_literal: true

require 'tty-box'
require 'tty-table'
require_relative 'layout'
require_relative 'content_builder'

module RubyMysqlTui
  module UI
    # Renderer は Layout に基づいて TUI 画面を描画します。
    class Renderer
      CLEAR_SCREEN = "\e[2J\e[H"

      def initialize(layout)
        @layout = layout
      end

      # 画面全体をレンダリングします。
      def render(client, state)
        @layout.update_dimensions
        print CLEAR_SCREEN

        render_header(client)
        render_main(state)
        render_log(client, state)
        render_footer(state)
      end

      private

      def render_header(client)
        text = "Host: #{client.config[:host]} | User: #{client.config[:username]} | DB: #{client.config[:database]}"
        puts TTY::Box.frame(width: @layout.width, height: @layout.header_h) { text }
      end

      def render_main(state)
        if state[:show_help]
          render_help_modal
        else
          left = build_box(@layout.left_w, left_content(state), state[:focus] == :left)
          right = build_box(@layout.right_w, right_content(state), state[:focus] == :right)
          render_side_by_side(left, right)
        end
      end

      def left_content(state)
        items = RubyMysqlTui::UI::ContentBuilder.filtered_items(state)
        ContentBuilder.build_list_text(items, state[:selected_index], @layout.left_w, @layout.main_h)
      end

      def right_content(state)
        # ContentBuilder にはページ内での相対的なオフセットを渡す
        if state[:view_mode] == :records
          relative_offset = (state[:records_offset] || 0) - (state[:page_offset] || 0)
          state = state.merge(records_offset: relative_offset)
        end
        ContentBuilder.build_right_text(state, @layout.right_w, @layout.main_h)
      end

      def build_box(width, content, focused)
        TTY::Box.frame(
          width: width, height: @layout.main_h,
          style: { border: { fg: focused ? :cyan : :white } }
        ) { content }
      end

      def render_side_by_side(left_box, right_box)
        left_lines = left_box.split("\n", -1)
        right_lines = right_box.split("\n", -1)
        max_lines = [left_lines.length, right_lines.length].max

        (0...max_lines).each do |i|
          puts "#{left_lines[i]}#{right_lines[i]}"
        end
      end

      def render_log(client, state)
        if state[:sql_mode]
          text = "SQL MODE: #{state[:sql_input]} (Esc to cancel)"
        elsif state[:status_message]
          text = "Status: #{state[:status_message]}"
        else
          sql = client.last_sql
          text = sql ? "Last SQL: #{sql}" : 'No SQL executed'
        end
        truncated_text = ContentBuilder.truncate(text, @layout.width - 2)
        puts TTY::Box.frame(width: @layout.width, height: @layout.log_h) { truncated_text }
      end

      def render_footer(state)
        guide = "#{footer_mode_text(state)}#{build_footer_guides(state).join(' | ')}"
        puts TTY::Box.frame(width: @layout.width, height: @layout.footer_h) { guide }
      end

      def footer_mode_text(state)
        text = state[:all_records_mode] ? '[ALL RECORDS MODE] ' : ''
        text += "[Filter: #{state[:filter_query]}] " if state[:filter_query] && !state[:filter_query].empty?
        text
      end

      def build_footer_guides(state)
        guides = ['[q] Quit', '[Tab] Switch Focus', '[?] Help']
        if state[:focus] == :left
          guides += ['[b] Back', '[↑/↓] Move', '[Enter] Select']
          guides << '[r] Rename' if state[:view_mode] == :tables
        elsif state[:focus] == :right
          guides += build_right_pane_guides(state)
        end
        guides
      end

      def build_right_pane_guides(state)
        case state[:view_mode]
        when :records then records_guides(state)
        when :table_structure then structure_guides
        when :record_detail
          ['[b/Esc] Back', '[↑/↓] Scroll', '[e] Edit',
           '[d] Delete', '[c] Clone', '[[/]] Prev/Next Rec']
        else []
        end
      end

      def records_guides(state)
        guides = ['[n] New', '[e] Edit', '[d] Delete', '[c] Clone', '[o] Sort']
        guides << (state[:all_records_mode] ? '[a] Normal Mode' : '[a] All Records')
        guides << '[i] Structure'
        guides << '[←/→] Scroll Cols'
        guides
      end

      def structure_guides
        ['[i] Records', '[↑/↓] Move', '[←/→] Scroll Cols']
      end

      def render_help_modal
        help_text = <<~HELP
          --- 操作ヘルプ ---

          [共通操作]
          [Tab] フォーカス切り替え | [q] 終了 | [s] SQLモード | [?] ヘルプを閉じる

          [左ペイン操作]
          [/] フィルタ入力 | [Enter] 選択 | [n] 新規作成 | [d] 削除 | [r] 名前変更

          [右ペイン操作]
          [n] 新規挿入 | [e] 編集 | [d] 削除 | [c] クローン | [o] ソート
          [i] 構造/レコード切替 | [←/→] カラムスクロール | [[/]] 前後レコード

          [Esc] フィルタクリア / 詳細ビューから戻る
        HELP
        puts TTY::Box.frame(
          width: @layout.width, height: @layout.main_h,
          style: { border: { fg: :cyan } }
        ) { help_text }
      end
    end
  end
end

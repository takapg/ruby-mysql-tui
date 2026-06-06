# frozen_string_literal: true

module RubyMysqlTui
  module UI
    # FooterBuilder は フッターのガイドテキスト構築ロジックを提供します。
    module FooterBuilder
      module_function

      def build_footer_guides(state)
        guides = ['[q] Quit', '[Tab] Switch Focus', '[?] Help']
        if state[:focus] == :left
          guides += ['[b] Back', '[↑/↓] Move', '[Enter] Select']
          guides << '[r] Rename' if state[:view_mode] == :tables
          guides << '[t] Truncate' if state[:view_mode] == :tables
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
        guides = ['[n] New', '[e] Edit', '[d] Delete', '[c] Clone', '[o] Sort', '[/] Filter']
        guides << (state[:all_records_mode] ? '[a] Normal Mode' : '[a] All Records')
        guides << '[i] Structure'
        guides << '[←/→] Scroll Cols'
        guides
      end

      def structure_guides
        ['[i] Records', '[n] Add Col', '[↑/↓] Move', '[←/→] Scroll Cols']
      end
    end
  end
end

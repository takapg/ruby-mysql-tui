# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # Navigation は 画面遷移やフォーカス移動などのナビゲーション処理を提供します。
    module Navigation
      module_function

      def handle_tab(state)
        state[:focus] = (state[:focus] == :left ? :right : :left)
        state
      end

      def handle_return(state, client)
        if state[:focus] == :left
          case state[:view_mode]
          when :databases then handle_databases_return(state, client)
          when :tables then handle_tables_return(state, client)
          end
        elsif state[:focus] == :right && state[:view_mode] == :records
          handle_records_return(state)
        end
        state
      end

      def handle_records_return(state)
        return if state[:records].empty?

        state[:view_mode] = :record_detail
        state[:detail_offset] = 0
      end

      def handle_databases_return(state, client)
        items = RubyMysqlTui::UI::ContentBuilder.filtered_items(state)
        return if items.empty?

        safe_index = state[:selected_index].clamp(0, items.size - 1)
        db_name = items[safe_index]
        client.select_database(db_name)
        apply_tables_view_state(state, db_name, client)
      end

      def apply_tables_view_state(state, db_name, client)
        state.merge!(
          selected_db: db_name, view_mode: :tables, items: client.list_tables(db_name),
          selected_index: 0, filter_query: '', records_filter_query: '', columns_offset: 0,
          sort_column: nil, sort_direction: 'ASC', sql_result_mode: false
        )
      end

      def handle_tables_return(state, client)
        items = RubyMysqlTui::UI::ContentBuilder.filtered_items(state)
        return if items.empty?

        safe_index = state[:selected_index].clamp(0, items.size - 1)
        table_name = items[safe_index]
        reset_record_state(state, table_name, client)
      end

      def reset_record_state(state, table_name, client)
        state.merge!(selected_table: table_name, view_mode: :records, page_offset: 0,
                     records_offset: 0, columns_offset: 0, sort_column: nil, sort_direction: 'ASC',
                     filter_query: '', records_filter_query: '', sql_result_mode: false)
        state[:records] = client.list_records(table_name, 0)
        state[:selected_record_index] = 0
      end

      def handle_back_navigation(state, client)
        return state if state[:view_mode] == :databases

        apply_databases_view_state(state, client)
        state
      end

      def apply_databases_view_state(state, client)
        state.merge!(
          view_mode: :databases, items: client.list_databases, selected_index: 0,
          filter_query: '', records_filter_query: '', selected_db: nil, selected_table: nil,
          page_offset: 0, records_offset: 0, columns_offset: 0, sql_result_mode: false
        )
      end
    end
  end
end

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
        return if state[:items].empty?

        db_name = state[:items][state[:selected_index]]
        client.select_database(db_name)
        state[:selected_db] = db_name
        state[:view_mode] = :tables
        state[:items] = client.list_tables(db_name)
        state[:selected_index] = 0
        state[:columns_offset] = 0
        state[:sort_column] = nil
        state[:sort_direction] = 'ASC'
      end

      def handle_tables_return(state, client)
        return if state[:items].empty?

        table_name = state[:items][state[:selected_index]]
        state[:selected_table] = table_name
        state[:view_mode] = :records
        state[:page_offset] = 0
        state[:records_offset] = 0
        state[:columns_offset] = 0
        state[:sort_column] = nil
        state[:sort_direction] = 'ASC'
        state[:records] = client.list_records(table_name, 0)
        state[:selected_record_index] = 0
      end

      def handle_back_navigation(state, client)
        return state if state[:view_mode] == :databases

        state[:view_mode] = :databases
        state[:items] = client.list_databases
        state[:selected_index] = 0
        state[:selected_db] = nil
        state[:selected_table] = nil
        state[:page_offset] = 0
        state[:records_offset] = 0
        state[:columns_offset] = 0
        state
      end
    end
  end
end

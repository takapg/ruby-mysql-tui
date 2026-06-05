# frozen_string_literal: true

require_relative 'database_manager'
require_relative 'table_manager'
require_relative 'record_manager'
require_relative 'record_sort_handler'
require_relative 'navigation'

module RubyMysqlTui
  module InputHandler
    # ActionHandler は システムアクションやレコード操作アクションのルーティングを提供します。
    module ActionHandler
      module_function

      def handle_action_key(val, state, client)
        case val
        when 'b', 's', 'i', "\t", "\r", 'a' then handle_system_action(val, state, client)
        when 'n', 'e', 'd', 'c', 'o' then handle_record_action(val, state, client)
        when '[', ']' then handle_record_navigation(val, state)
        end
      end

      def handle_record_navigation(val, state)
        return state unless state[:view_mode] == :record_detail

        delta = (val == ']') ? 1 : -1
        new_index = (state[:selected_record_index] || 0) + delta
        state[:selected_record_index] = new_index.clamp(0, (state[:records] || []).size - 1)
        state[:detail_offset] = 0
        state
      end

      def handle_system_action(val, state, client)
        case val
        when 'b' then Navigation.handle_back_navigation(state, client)
        when 's' then RubyMysqlTui::InputHandler.handle_sql_mode_toggle(state)
        when 'i' then RubyMysqlTui::InputHandler.handle_view_mode_toggle(state, client)
        when "\t" then Navigation.handle_tab(state)
        when "\r" then Navigation.handle_return(state, client)
        when 'a' then RecordManager.handle_all_records_toggle(state, client)
        else state
        end
      end

      def handle_record_action(val, state, client)
        prompt = TTY::Prompt.new
        case val
        when 'n' then handle_new_record_action(state, client, prompt)
        when 'e' then RecordManager.handle_edit_record(state, client, prompt)
        when 'd' then handle_delete_action(state, client, prompt)
        when 'c' then RecordManager.handle_clone_record(state, client, prompt)
        when 'o' then RecordSortHandler.handle_sort_record(state, client, prompt)
        else state
        end
      end

      def handle_delete_action(state, client, prompt)
        case state[:view_mode]
        when :databases
          DatabaseManager.handle_drop_database(state, client, prompt)
        when :tables
          TableManager.handle_drop_table(state, client, prompt)
        else
          RecordManager.handle_delete_record(state, client, prompt)
        end
      end

      def handle_new_record_action(state, client, prompt)
        if state[:view_mode] == :databases
          DatabaseManager.handle_create_database(state, client, prompt)
        elsif state[:view_mode] == :tables
          TableManager.handle_create_table(state, client, prompt)
        else
          RecordManager.handle_create_record(state, client, prompt)
        end
      end
    end
  end
end

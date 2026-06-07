# frozen_string_literal: true

require_relative 'database_manager'
require_relative 'table_manager'
require_relative 'record_manager'
require_relative 'record_sort_handler'
require_relative 'navigation'
require_relative 'value_viewer'
require_relative 'action_dispatcher'

module RubyMysqlTui
  module InputHandler
    # ActionHandler は システムアクションやレコード操作アクションのルーティングを提供します。
    module ActionHandler
      module_function

      def handle_action_key(val, state, client)
        case val
        when 'b', 's', 'i', "\t", "\r", 'a' then handle_system_action(val, state, client)
        when 'n', 'e', 'd', 'c', 'o', 'r', 't', 'v', 'm', "\x05" then handle_record_action(val, state, client)
        when '[', ']' then handle_record_navigation(val, state)
        end
      end

      def handle_record_navigation(val, state)
        return state unless state[:view_mode] == :record_detail

        records = state[:records] || []
        return state if records.empty?

        delta = val == ']' ? 1 : -1
        new_index = (state[:selected_record_index] || 0) + delta
        state[:selected_record_index] = new_index.clamp(0, records.size - 1)
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
        when 'n', 'd', 'c' then handle_record_lifecycle_action(val, state, client, prompt)
        when 'e', 'o', 'r', 't', 'v', 'm', "\x05" then handle_record_utility_action(val, state, client, prompt)
        else state
        end
      end

      private_class_method def handle_record_lifecycle_action(val, state, client, prompt)
        case val
        when 'n' then ActionDispatcher.handle_new_record_action(state, client, prompt)
        when 'd' then ActionDispatcher.handle_delete_action(state, client, prompt)
        when 'c' then RecordManager.handle_clone_record(state, client, prompt)
        end
      end

      private_class_method def handle_record_utility_action(val, state, client, prompt)
        case val
        when 'e', 'o', 'r', 't' then handle_utility_edit_actions(val, state, client, prompt)
        when 'v', 'm', "\x05" then handle_utility_view_actions(val, state, client, prompt)
        else state
        end
      end

      private_class_method def handle_utility_edit_actions(val, state, client, prompt)
        case val
        when 'e' then RecordManager.handle_edit_record(state, client, prompt)
        when 'o' then RecordSortHandler.handle_sort_record(state, client, prompt)
        when 'r' then ActionDispatcher.handle_rename_action(state, client, prompt)
        when 't' then ActionDispatcher.handle_truncate_action(state, client, prompt)
        end
      end

      private_class_method def handle_utility_view_actions(val, state, client, prompt)
        case val
        when 'v' then ActionDispatcher.handle_view_value_action(state)
        when 'm' then ActionDispatcher.handle_modify_action(state, client, prompt)
        when "\x05" then RecordManager.handle_external_edit(state, client, prompt)
        end
      end
    end
  end
end

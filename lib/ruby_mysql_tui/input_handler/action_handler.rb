# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # ActionHandler は システムアクションやレコード操作アクションのルーティングを提供します。
    module ActionHandler
      module_function

      def handle_action_key(val, state, client)
        case val
        when 'b', 's', 'i', "\t", "\r", 'a' then handle_system_action(val, state, client)
        when 'n', 'e', 'd' then handle_record_action(val, state, client)
        end
      end

      def handle_system_action(val, state, client)
        case val
        when 'b' then Navigation.handle_back_navigation(state, client)
        when 's' then RubyMysqlTui::InputHandler.handle_sql_mode_toggle(state)
        when 'i' then RubyMysqlTui::InputHandler.handle_view_mode_toggle(state, client)
        when "\t" then Navigation.handle_tab(state)
        when "\r" then Navigation.handle_return(state, client)
        when 'a' then RecordManager.handle_all_records_toggle(state, client)
        end
      end

      def handle_record_action(val, state, client)
        prompt = TTY::Prompt.new
        case val
        when 'n' then RecordManager.handle_create_record(state, client, prompt)
        when 'e' then RecordManager.handle_edit_record(state, client, prompt)
        when 'd' then RecordManager.handle_delete_record(state, client, prompt)
        end
      end
    end
  end
end

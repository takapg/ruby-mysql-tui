# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordToggleManager は 全レコード表示モードの切り替えを提供します。
    module RecordToggleManager
      module_function

      def handle_all_records_toggle(state, client)
        return state unless can_toggle_all_records?(state)

        state[:all_records_mode] = !state[:all_records_mode]
        apply_all_records_mode(state, client)
        state
      end

      def can_toggle_all_records?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:selected_table]
      end

      def apply_all_records_mode(state, client)
        opts = InputHandler.query_options(state)
        if state[:all_records_mode]
          state[:records] = client.list_records(
            state[:selected_table], 0, limit: RubyMysqlTui::Client::MAX_RECORDS_LIMIT, **opts
          )
          state[:page_offset] = 0
        else
          state[:page_offset] = state[:records_offset] || 0
          state[:records] = client.list_records(state[:selected_table], state[:page_offset], **opts)
        end
      end
    end
  end
end

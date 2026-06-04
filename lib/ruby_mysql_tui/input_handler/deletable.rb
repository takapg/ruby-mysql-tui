# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # Deletable は 削除操作に共通する状態更新およびエラーハンドリングを提供します。
    module Deletable
      module_function

      def cancel_deletion(state)
        state[:status_message] = 'Deletion cancelled'
        state
      end

      def handle_drop_error(prompt, error, state, entity_name)
        RubyMysqlTui.logger.error("#{entity_name} Drop Error: #{error.message}")
        prompt.error("エラーが発生しました: #{error.message}")
        state
      end

      def update_state_after_deletion(state, items)
        state[:items] = items
        state[:selected_index] = state[:selected_index].clamp(0, [0, state[:items].size - 1].max)
        state
      end
    end
  end
end

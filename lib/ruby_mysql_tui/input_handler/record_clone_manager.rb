# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordCloneManager は レコードの複製操作を提供します。
    module RecordCloneManager
      module_function

      def handle_clone_record(state, client, prompt)
        return state unless RecordManager.can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        return state unless record

        data, info = gather_clone_data(state, client, prompt, record)
        return state if data.nil? || data.empty?

        RecordRetryHandler.execute_insert_with_retry(state, client, prompt, data, info)
        state
      end

      def gather_clone_data(state, client, prompt, record)
        pk_col = client.primary_key_for(state[:selected_table])
        cols = client.list_columns(state[:selected_table])
        struct = client.list_table_structure(state[:selected_table])
        data = RecordPrompt.prompt_for_record_data(cols, prompt, record.reject { |k, _| k == pk_col }, struct)
        [data, { columns: cols, structure: struct }]
      end
    end
  end
end

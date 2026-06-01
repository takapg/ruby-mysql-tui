# frozen_string_literal: true

require_relative 'input_handler/sql'

module RubyMysqlTui
  # InputHandler は ユーザー入力を処理し、状態を更新します。
  module InputHandler
    module_function

    def handle_input(event, state, client)
      return handle_back_navigation(state, client) if event.value == 'b'
      return handle_sql_mode_toggle(state) if event.value == 's'

      case event.key.name
      when :tab then handle_tab(state)
      when :up then handle_up(state)
      when :down then handle_down(state)
      when :return then handle_return(state, client)
      else state
      end
    end

    def handle_tab(state)
      state[:focus] = (state[:focus] == :left ? :right : :left)
      state
    end

    def handle_up(state)
      if state[:focus] == :left && !state[:items].empty?
        state[:selected_index] = (state[:selected_index] - 1).clamp(0, state[:items].size - 1)
      end
      state
    end

    def handle_down(state)
      if state[:focus] == :left && !state[:items].empty?
        state[:selected_index] = (state[:selected_index] + 1).clamp(0, state[:items].size - 1)
      end
      state
    end

    def handle_return(state, client)
      return state unless state[:focus] == :left

      case state[:view_mode]
      when :databases then handle_databases_return(state, client)
      when :tables then handle_tables_return(state, client)
      end
      state
    end

    def handle_databases_return(state, client)
      return if state[:items].empty?

      db_name = state[:items][state[:selected_index]]
      state[:selected_db] = db_name
      state[:view_mode] = :tables
      state[:items] = client.list_tables(db_name)
      state[:selected_index] = 0
    end

    def handle_tables_return(state, client)
      return if state[:items].empty?

      table_name = state[:items][state[:selected_index]]
      state[:selected_table] = table_name
      state[:view_mode] = :records
      state[:records] = client.list_records(table_name)
    end

    def handle_back_navigation(state, client)
      return state if state[:view_mode] == :databases

      state[:view_mode] = :databases
      state[:items] = client.list_databases
      state[:selected_index] = 0
      state[:selected_db] = nil
      state[:selected_table] = nil
      state
    end

    def handle_sql_mode_toggle(state)
      state[:sql_mode] = !state[:sql_mode]
      state[:sql_input] = '' if state[:sql_mode]
      state
    end

  end
end

# frozen_string_literal: true

require 'tty-prompt'
require_relative 'input_handler/sql'
require_relative 'input_handler/pagination'
require_relative 'input_handler/record_manager'
require_relative 'input_handler/navigation'
require_relative 'ui/layout'

module RubyMysqlTui
  # InputHandler は ユーザー入力を処理し、状態を更新します。
  module InputHandler
    module_function

    def handle_input(event, state, client)
      val = event.respond_to?(:value) ? event.value : event

      if (result = handle_action_key(val, state, client))
        return result
      end

      key_name = extract_key_name(event)
      key_name = key_name.to_sym if key_name.is_a?(String)
      handle_key_input(key_name, state, client)
    end

    def extract_key_name(event)
      if event.respond_to?(:key) && event.key.respond_to?(:name)
        event.key.name
      elsif event.respond_to?(:name)
        event.name
      end
    end

    def handle_action_key(val, state, client)
      case val
      when 'b' then Navigation.handle_back_navigation(state, client)
      when 's' then handle_sql_mode_toggle(state)
      when 'i' then handle_view_mode_toggle(state, client)
      when 'n' then RecordManager.handle_create_record(state, client, TTY::Prompt.new)
      when 'e' then RecordManager.handle_edit_record(state, client, TTY::Prompt.new)
      when 'd' then RecordManager.handle_delete_record(state, client, TTY::Prompt.new)
      end
    end

    def handle_key_input(key_name, state, client)
      case key_name
      when :tab then Navigation.handle_tab(state)
      when :up then handle_up(state, client)
      when :down then handle_down(state, client)
      when :return then Navigation.handle_return(state, client)
      else state
      end
    end

    def handle_up(state, client)
      handle_scroll(state, client, -1)
    end

    def handle_down(state, client)
      handle_scroll(state, client, 1)
    end

    def handle_scroll(state, client, delta)
      if state[:focus] == :left && !state[:items].empty?
        update_selected_index(state, delta)
      elsif state[:focus] == :right && state[:view_mode] == :records && state[:records]
        Pagination.update_records_offset(state, delta, client, current_layout)
      end
      state
    end

    def update_selected_index(state, delta)
      state[:selected_index] = (state[:selected_index] + delta).clamp(0, state[:items].size - 1)
    end

    def current_layout
      @current_layout ||= RubyMysqlTui::UI::Layout.new
      @current_layout.update_dimensions
      @current_layout
    end

    def handle_sql_mode_toggle(state)
      state[:sql_mode] = !state[:sql_mode]
      state[:sql_input] = '' if state[:sql_mode]
      state
    end

    def handle_view_mode_toggle(state, client)
      return state unless state[:focus] == :right && state[:selected_table]

      if state[:view_mode] == :records
        state[:view_mode] = :table_structure
        state[:records] = client.list_table_structure(state[:selected_table])
      elsif state[:view_mode] == :table_structure
        state[:view_mode] = :records
        state[:records] = client.list_records(state[:selected_table], state[:records_offset] || 0)
      end
      state
    end
  end
end

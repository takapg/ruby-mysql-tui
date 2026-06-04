# frozen_string_literal: true

require 'tty-prompt'
require_relative 'input_handler/sql'
require_relative 'input_handler/pagination'
require_relative 'input_handler/record_manager'
require_relative 'input_handler/navigation'
require_relative 'input_handler/action_handler'
require_relative 'ui/layout'

module RubyMysqlTui
  # InputHandler は ユーザー入力を処理し、状態を更新します。
  module InputHandler
    module_function

    def handle_input(event, state, client)
      state[:status_message] = nil
      val = event.respond_to?(:value) ? event.value : event

      return state.merge(view_mode: :records) if detail_back_pressed?(val, state)
      return handle_arrow_keys(val, state, client) if arrow_key?(val)

      ActionHandler.handle_action_key(val, state, client) ||
        handle_key_input(extract_key_name(event), state, client)
    end

    private_class_method def detail_back_pressed?(val, state)
      state[:view_mode] == :record_detail && ['b', "\e"].include?(val)
    end

    private_class_method def arrow_key?(val)
      ['\e[A', '\eOA', '\e[B', '\eOB', '\e[C', '\e[D'].include?(val)
    end

    private_class_method def handle_arrow_keys(val, state, client)
      case val
      when "\e[A", "\eOA" then handle_up(state, client)
      when "\e[B", "\eOB" then handle_down(state, client)
      when "\e[C" then handle_column_scroll(state, 1)
      when "\e[D" then handle_column_scroll(state, -1)
      end
    end

    def extract_key_name(event)
      event.respond_to?(:key) && event.key.respond_to?(:name) ? event.key.name : nil
    end

    def handle_key_input(key_name, state, client)
      case key_name
      when :tab then Navigation.handle_tab(state)
      when :up then handle_up(state, client)
      when :down then handle_down(state, client)
      when :left then handle_column_scroll(state, -1)
      when :right then handle_column_scroll(state, 1)
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

    def handle_column_scroll(state, delta)
      return state unless state[:focus] == :right && state[:records]

      total_cols = state[:records].first&.keys&.size || 0
      state[:columns_offset] = ((state[:columns_offset] || 0) + delta).clamp(0, [0, total_cols - 1].max)
      state
    end

    def handle_scroll(state, client, delta)
      if state[:focus] == :left
        handle_left_scroll(state, delta)
      elsif state[:focus] == :right
        handle_right_scroll(state, client, delta)
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

    private_class_method def handle_left_scroll(state, delta)
      update_selected_index(state, delta) unless state[:items].empty?
    end

    private_class_method def handle_right_scroll(state, client, delta)
      return unless state[:records]

      case state[:view_mode]
      when :records then scroll_records(state, client, delta)
      when :table_structure then scroll_structure(state, delta)
      when :record_detail then scroll_detail(state, delta)
      end
      state
    end

    private_class_method def scroll_records(state, client, delta)
      Pagination.update_records_offset(state, delta, client, current_layout)
    end

    private_class_method def scroll_structure(state, delta)
      state[:records_offset] = ((state[:records_offset] || 0) + delta).clamp(0, state[:records].size)
    end

    private_class_method def scroll_detail(state, delta)
      record = state[:records][state[:selected_record_index]]
      return unless record

      state[:records_offset] = ((state[:records_offset] || 0) + delta).clamp(0, record.keys.size)
    end
  end
end

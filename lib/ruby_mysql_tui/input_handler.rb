# frozen_string_literal: true

require 'tty-prompt'
require_relative 'input_handler/sql'
require_relative 'input_handler/pagination'
require_relative 'input_handler/record_manager'
require_relative 'input_handler/navigation'
require_relative 'input_handler/action_handler'
require_relative 'input_handler/scroll_handler'
require_relative 'ui/layout'

module RubyMysqlTui
  # InputHandler は ユーザー入力を処理し、状態を更新します。
  module InputHandler
    module_function

    def handle_input(event, state, client)
      val = event.respond_to?(:value) ? event.value : event
      return state.merge(show_help: false) if state[:show_help]

      state[:status_message] = nil
      handle_special_keys(val, state) ||
        handle_navigation_and_actions(val, event, state, client)
    end

    private_class_method def handle_special_keys(val, state)
      return handle_filter_input(val, state) if state[:focus] == :left && ['/', "\e"].include?(val)
      return state.merge(show_help: true) if val == '?'
      nil
    end

    private_class_method def handle_navigation_and_actions(val, event, state, client)
      return state.merge(view_mode: :records) if detail_back_pressed?(val, state)
      return handle_arrow_keys(val, state, client) if arrow_key?(val)

      ActionHandler.handle_action_key(val, state, client) ||
        handle_key_input(extract_key_name(event), state, client)
    end

    private_class_method def handle_filter_input(val, state)
      if val == '/'
        prompt = TTY::Prompt.new
        query = prompt.ask('フィルターキーワードを入力:')
        state.merge(filter_query: query || '', selected_index: 0)
      elsif val == "\e" && state[:filter_query] && !state[:filter_query].empty?
        state.merge(filter_query: '', selected_index: 0)
      else
        state
      end
    end

    private_class_method def detail_back_pressed?(val, state)
      state[:view_mode] == :record_detail && ['b', "\e"].include?(val)
    end

    private_class_method def arrow_key?(val)
      ["\e[A", "\eOA", "\e[B", "\eOB", "\e[C", "\e[D"].include?(val)
    end

    private_class_method def handle_arrow_keys(val, state, client)
      case val
      when "\e[A", "\eOA" then ScrollHandler.handle_up(state, client)
      when "\e[B", "\eOB" then ScrollHandler.handle_down(state, client)
      when "\e[C" then ScrollHandler.handle_column_scroll(state, 1)
      when "\e[D" then ScrollHandler.handle_column_scroll(state, -1)
      else state
      end
    end

    def extract_key_name(event)
      event.respond_to?(:key) && event.key.respond_to?(:name) ? event.key.name : nil
    end

    def handle_key_input(key_name, state, client)
      case key_name
      when :tab then Navigation.handle_tab(state)
      when :up then ScrollHandler.handle_up(state, client)
      when :down then ScrollHandler.handle_down(state, client)
      when :left then ScrollHandler.handle_column_scroll(state, -1)
      when :right then ScrollHandler.handle_column_scroll(state, 1)
      when :return then Navigation.handle_return(state, client)
      else state
      end
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

    def self.sort_options(state)
      state[:sort_column] ? { sort_column: state[:sort_column], sort_direction: state[:sort_direction] } : {}
    end
  end
end

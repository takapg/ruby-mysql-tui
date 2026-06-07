# frozen_string_literal: true

module RubyMysqlTui
  # ConnectionManager は MySQL への接続確立と再試行プロンプトを管理します。
  module ConnectionManager
    def self.establish_connection
      config = nil
      begin
        return try_connect(config)
      rescue Mysql2::Error => e
        config = handle_connection_failure(e)
        return nil unless config
        retry
      end
    end

    def self.try_connect(config)
      client = Client.new(config || {})
      verify_connection(client)
      client
    rescue Mysql2::Error => e
      client&.close
      raise e
    end

    def self.verify_connection(client)
      client.query('SELECT 1')
      RubyMysqlTui.logger.info 'MySQL connection verified.'
    end

    def self.handle_connection_failure(error)
      RubyMysqlTui.logger.error "Connection failed: #{error.message}"
      prompt = TTY::Prompt.new
      return nil unless prompt.yes?('接続に失敗しました。接続情報を再入力しますか？')

      prompt_config(prompt)
    end

    def self.prompt_config(prompt)
      {
        host: prompt.ask('Host:', default: 'localhost'),
        username: prompt.ask('Username:', default: 'root'),
        password: prompt.mask('Password:'),
        database: prompt.ask('Database (optional):')
      }
    end

    private_class_method :try_connect, :verify_connection, :handle_connection_failure, :prompt_config
  end
end

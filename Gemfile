# frozen_string_literal: true

source 'https://rubygems.org'

ruby file: '.ruby-version'

gem 'logger'
gem 'mysql2'

# tty-toolkit の必要なコンポーネントを個別に指定
gem 'tty-box'      # 枠線の描画用
gem 'tty-screen'   # ターミナルサイズ取得用
gem 'tty-table'    # 右ペインのテーブル表示用
gem 'tty-reader'   # キーボード入力のリアルタイム検知用
gem 'tty-prompt'   # インプットフォーム、確認ダイアログ用

group :development, :test do
  gem 'rspec'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
end

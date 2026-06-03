# ruby-mysql-tui

## 起動方法

Docker を使用してローカル環境で起動する場合、以下の手順で実行してください。

1. MySQL データベースを起動します。
   ```bash
   docker compose up -d
   ```

2. アプリケーションイメージをビルドします。
   ```bash
   docker compose -f docker-compose.app.yml build
   ```

3. アプリケーションを起動します。
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.app.yml run --rm app
   ```

# 一斉電話発信アプリケーション

## 概要

このアプリケーションは、Twilio APIを利用して、指定された複数の電話番号に一斉に電話を発信するFlaskアプリケーションです。
環境変数から読み込んだカンマ区切りの電話番号リストに対して、順番に発信処理を行います。
エンドポイントはHTTP Basic認証によって保護されています。

## 必要な環境変数

このアプリケーションを実行するには、以下の環境変数を設定する必要があります。

- `APP_USER`: Basic認証のユーザー名
- `APP_PASSWORD`: Basic認証のパスワード
- `TWILIO_ACCOUNT_SID`: ご自身のTwilioアカウントSID
- `TWILIO_AUTH_TOKEN`: ご自身のTwilio認証トークン
- `FROM_PHONE_NUMBER`: 発信元となるTwilioの電話番号
- `TO_PHONE_NUMBER`: 発信先の電話番号（カンマ区切りで複数指定可能 例: `"+819012345678,+818012345678"`）

## Dockerでの実行方法

1. **Dockerイメージのビルド:**
   ```bash
   docker build -t bulk-call-app .
   ```

2. **Dockerコンテナの実行:**
   プレースホルダーの値を実際のものに置き換えて実行してください。
   ```bash
   docker run -d \
     -p 8080:8080 \
     -e APP_USER="your_username" \
     -e APP_PASSWORD="your_password" \
     -e TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
     -e TWILIO_AUTH_TOKEN="your_auth_token" \
     -e FROM_PHONE_NUMBER="+15017122661" \
     -e TO_PHONE_NUMBER="+819012345678,+818012345678" \
     --name bulk-call-container \
     bulk-call-app
   ```

3. **アプリケーションのトリガー:**
   ルートURL (`/`) に対してGETまたはPOSTリクエストを送信することで、電話発信が開始されます。
   ```bash
   curl -u "your_username:your_password" http://localhost:8080/
   ```

## セキュリティに関する考慮事項

このアプリケーションはHTTP Basic認証を使用しています。暗号化されていない通信路上では安全ではありません。
TLS暗号化(HTTPS)を提供するリバースプロキシの背後で実行することを強く推奨します。

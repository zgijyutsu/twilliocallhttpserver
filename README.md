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

## Google Cloud Runでの実行方法

1. **Dockerイメージのビルド:**
   ```bash
   docker build -t bulk-call-app .
   ```
   （Google Cloudへプッシュする際は、`gcloud builds submit --tag gcr.io/your-project-id/bulk-call-app` のようなコマンドを使用します）

2. **Cloud Runへのデプロイ:**
   コンソールまたはgcloudコマンドを使用して、ビルドしたイメージをCloud Runにデプロイします。
   その際、上記の「必要な環境変数」をすべて設定してください。

3. **アプリケーションのトリガー:**
   Cloud Runから提供されるHTTPS URLに対して、GETまたはPOSTリクエストを送信することで、電話発信が開始されます。
   ```bash
   curl -u "your_username:your_password" https://your-cloud-run-service-url/
   ```

## セキュリティに関する考慮事項

このアプリケーションは、Google Cloud Runのようなリバースプロキシ環境での実行を前提として設計されています。

### HTTPSの強制
Google Cloud Runは、全てのサービスにTLS証明書を自動でプロビジョニングし、HTTPS通信を終端します。
本アプリケーションは、リバースプロキシから送信される `X-Forwarded-Proto` ヘッダーを検証し、本番環境（非デバッグモード）ではHTTPS接続以外からのリクエストを自動的に拒否するよう設定されています。
これにより、Basic認証の情報が暗号化されていないHTTP通信で送信されることを防ぎます。

### ローカルでのテスト
ローカル環境で `docker run` を使用してテストする場合、HTTPS強制は無効になります（Flaskのデバッグモードが有効なため）。
その際のURLは `http://localhost:8080/` となります。

# Twilio 一斉架電サーバー

これは、[Twilio](https://www.twilio.com/ja/) を利用して、指定した複数の電話番号に一斉に電話を発信する Flask アプリケーションです。
Google Cloud Run 上での動作を想定しており、Terraform によるインフラのコード化 (IaC) と、GitHub Actions を用いた CI/CD パイプラインが構築されています。

## アーキテクチャ概要

![architecture_diagram](https'://user-images.githubusercontent.com/12345/67890.png')
<!-- ↑ あとで画像へのリンクを貼る -->

- **ソースコード管理**: GitHub
- **CI/CD**: GitHub Actions
- **コンテナイメージ管理**: Google Artifact Registry
- **アプリケーション実行環境**: Google Cloud Run
- **機密情報管理**: Google Secret Manager
- **認証**:
    - **Cloud Run へのアクセス**: HTTP Basic 認証
    - **GitHub Actions から Google Cloud へ**: Workload Identity Federation (WIF)

## 主な機能

- **環境変数からの設定**:
    - Twilio アカウント情報 (SID, Auth Token)
    - 発信元・発信先の電話番号
    - Basic 認証のユーザー名・パスワード
- **複数番号への一斉発信**: 環境変数 `TO_PHONE_NUMBER` にカンマ区切りで複数の番号を指定できます。
- **HTTPS 強制**: `main.py` で、Cloud Run のようなリバースプロキシ環境下でも適切にリクエストの `scheme` を判定し、本番環境では HTTPS を強制します。
- **コンテナ化**: `Dockerfile` により、アプリケーションの実行環境をコンテナとして定義しています。
- **IaC**: Terraform を使用して、以下の Google Cloud リソースをコードで管理します。
    - Cloud Run サービス
    - Artifact Registry リポジトリ
    - Secret Manager のシークレット定義
    - Workload Identity Federation の設定
    - GitHub Actions 用のサービスアカウントと権限 (IAM)
    - Terraform の状態 (state) を保存する GCS バケット
- **自動デプロイ**:
    - `main` ブランチへの push をトリガーに、GitHub Actions が起動します。
    - Terraform を実行してインフラを構成 (`terraform apply`)。
    - Docker イメージをビルドし、Artifact Registry へ push。
    - 新しいイメージを Cloud Run へデプロイ。

---

## 🛠️ セットアップ手順

このプロジェクトをあなたの環境で動かすためには、いくつかの事前準備が必要です。

### 1. Google Cloud プロジェクトの準備

1.  Google Cloud プロジェクトを作成または選択します。
2.  以下の API を有効にします。
    - Cloud Run API (`run.googleapis.com`)
    - Artifact Registry API (`artifactregistry.googleapis.com`)
    - Secret Manager API (`secretmanager.googleapis.com`)
    - Cloud Resource Manager API (`cloudresourcemanager.googleapis.com`)
    - Identity and Access Management (IAM) API (`iam.googleapis.com`)
    - Cloud Storage API (`storage.googleapis.com`)
3.  プロジェクトで課金を有効にします。

### 2. GitHub リポジトリの準備

1.  このリポジトリを自身の GitHub アカウントにフォークまたはクローンします。
2.  リポジトリの **[Settings] > [Secrets and variables] > [Actions]** に進み、以下の **Repository secrets** を登録します。これらは GitHub Actions のワークフローから参照されます。

| シークレット名 | 説明 |
| :--- | :--- |
| `PROJECT_ID` | あなたの Google Cloud プロジェクト ID。 |
| `WIF_PROVIDER` | Workload Identity Pool Provider のリソース名。<br>Terraform apply 後に出力される `workload_identity_provider` の値を設定します。 |
| `WIF_SERVICE_ACCOUNT` | GitHub Actions が使用するサービスアカウントのメールアドレス。<br>Terraform apply 後に出力される `service_account_email` の値を設定します。 |

### 3. Terraform の初期設定と初回デプロイ

Terraform の state は GCS バケットで管理されますが、そのバケット自体を最初に作成する必要があります。
**この初回セットアップは、Google Cloud プロジェクトのオーナー権限を持つアカウントで実行してください。**

1.  **ローカル環境の準備**:
    - `gcloud` CLI をインストール・初期化します (`gcloud init`)。
    - Terraform CLI をインストールします。

2.  **Terraform の実行**:
    リポジトリのルートで以下のコマンドを実行します。

    ```bash
    # Google Cloud にログイン
    gcloud auth application-default login

    # 環境変数を設定
    export TF_VAR_project_id="YOUR_PROJECT_ID"
    export TF_VAR_github_repository="YOUR_GITHUB_OWNER/YOUR_GITHUB_REPO"

    # Terraform を初期化
    # バックエンド (GCS) の設定もここで行う
    cd terraform
    terraform init

    # state を保存するための GCS バケットを作成
    terraform apply -target=google_storage_bucket.tfstate

    # GCS バックエンドを有効にして再度初期化
    terraform init -migrate-state

    # 全てのリソースをデプロイ
    terraform apply
    ```

3.  **GitHub Secrets の設定**:
    `terraform apply` の最後に出力される `workload_identity_provider` と `service_account_email` の値を、ステップ 2-2 で説明した GitHub の `WIF_PROVIDER` と `WIF_SERVICE_ACCOUNT` にそれぞれ設定します。

### 4. Secret Manager への機密情報の登録

以下の機密情報を Google Cloud の Secret Manager に登録します。
`gcloud` コマンドを使用する例を示します。

```bash
PROJECT_ID="YOUR_PROJECT_ID"

# Twilio 認証情報
gcloud secrets versions add TWILIO_ACCOUNT_SID --data-file=- --project=$PROJECT_ID <<< "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
gcloud secrets versions add TWILIO_AUTH_TOKEN --data-file=- --project=$PROJECT_ID <<< "your_twilio_auth_token"

# Basic 認証情報
gcloud secrets versions add APP_USER --data-file=- --project=$PROJECT_ID <<< "user"
gcloud secrets versions add APP_PASSWORD --data-file=- --project=$PROJECT_ID <<< "password"

# 電話番号
gcloud secrets versions add FROM_PHONE_NUMBER --data-file=- --project=$PROJECT_ID <<< "+15005550006"
gcloud secrets versions add TO_PHONE_NUMBER --data-file=- --project=$PROJECT_ID <<< "+819012345678,+818012345678"
```

**注意**: 上記の値はダミーです。ご自身の情報に置き換えてください。

### 5. デプロイの実行

これで全ての準備が整いました。
`main` ブランチに push すると、GitHub Actions が自動的にトリガーされ、Cloud Run へのデプロイが実行されます。

---

## 📞 アプリケーションの実行方法

デプロイが成功すると、Cloud Run サービスの URL が発行されます。
このエンドポイントに対して、Basic 認証の情報を付与して POST リクエストを送信することで、電話が発信されます。

```bash
# 環境変数を設定
SERVICE_URL=$(gcloud run services describe twilio-call-server --platform managed --region asia-northeast1 --format 'value(status.url)')
APP_USER=$(gcloud secrets versions access latest --secret="APP_USER" --project="YOUR_PROJECT_ID")
APP_PASSWORD=$(gcloud secrets versions access latest --secret="APP_PASSWORD" --project="YOUR_PROJECT_ID")

# cURL を使ってリクエスト
curl -X POST $SERVICE_URL \
     -u "$APP_USER:$APP_PASSWORD" \
     -v
```

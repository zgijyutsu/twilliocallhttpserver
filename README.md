# 一斉電話発信アプリケーション (Cloud Run & CI/CD対応版)

## 概要

このアプリケーションは、Twilio APIを利用して、指定された複数の電話番号に一斉に電話を発信するFlaskアプリケーションです。

Google Cloud Runでの運用を前提としており、インフラストラクチャの構築はTerraformによってコード管理されています。
また、GitHub Actionsを用いたCI/CDパイプラインが設定されており、`main`ブランチにコードをプッシュするだけで、自動的にDockerイメージのビルドとCloud Runへのデプロイが実行されます。

## 特徴

- **インフラのコード化 (IaC):** Terraformを用いてCloud Run、Artifact Registry、Secret ManagerなどのGoogle Cloudリソースを宣言的に管理します。
- **自動デプロイ:** GitHub Actionsにより、`main`ブランチへのプッシュをトリガーに、ビルドからデプロイまでを自動化します。
- **セキュアな認証:** Workload Identity Federationを利用し、サービスアカウントキー（JSONファイル）を使わずにGitHub ActionsからGoogle Cloudへ安全に認証します。
- **機密情報の保護:** Twilioの認証情報などの機密情報は、Secret Managerで安全に管理し、実行時にコンテナへ環境変数として渡されます。

---

## 構築・デプロイ手順

### ステップ1: 事前準備

1.  **Google Cloud プロジェクトの準備:**
    -   課金が有効になっているGoogle Cloudプロジェクトを用意します。
    -   以下のAPIを有効化しておきます。
        -   Cloud Run API (`run.googleapis.com`)
        -   Artifact Registry API (`artifactregistry.googleapis.com`)
        -   Secret Manager API (`secretmanager.googleapis.com`)
        -   IAM API (`iam.googleapis.com`)
        -   Cloud Build API (`cloudbuild.googleapis.com`) ※Artifact Registryが内部で使用

2.  **ツールのインストール:**
    -   [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
    -   [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)

3.  **gcloud CLIの認証:**
    ```bash
    gcloud auth login
    gcloud config set project YOUR_PROJECT_ID
    ```

### ステップ2: Terraformによるインフラ構築

1.  `terraform`ディレクトリに移動します。
    ```bash
    cd terraform
    ```

2.  `terraform.tfvars`ファイルを作成し、ご自身のプロジェクトIDを記述します。
    ```tfvars
    # terraform.tfvars
    project_id = "your-gcp-project-id"
    ```
    また、`main.tf`内の`google_service_account_iam_member.wif_binding`リソースにある`member`の末尾をご自身のGitHubリポジトリ名 (`your-github-org/your-repo-name`) に書き換えてください。

3.  Terraformを初期化し、実行計画を確認、適用します。
    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

4.  実行後、**2つの重要な値**が出力されます。これらは次のステップで使用するため、必ず控えておいてください。
    -   `workload_identity_provider`
    -   `service_account_email`

### ステップ3: GitHub Actions の Secrets 設定

1.  デプロイ対象のGitHubリポジトリで、`Settings` > `Secrets and variables` > `Actions` に移動します。

2.  `New repository secret`をクリックし、以下の2つのSecretを登録します。
    -   **`WIF_PROVIDER`**: Terraformの出力 `workload_identity_provider` の値を設定します。
    -   **`WIF_SERVICE_ACCOUNT`**: Terraformの出力 `service_account_email` の値を設定します。

3.  `.github/workflows/deploy.yml`内の`PROJECT_ID`をご自身のものに書き換えるか、同様にActions Secretとして登録して `${{ secrets.PROJECT_ID }}` のように参照を修正してください。

### ステップ4: 機密情報 (Twilio情報など) の設定

TerraformはSecret Managerにシークレットの「入れ物」を作成しただけなので、中に実際の値を入れる必要があります。

1.  Google Cloudコンソールの[Secret Managerページ](https://console.cloud.google.com/security/secret-manager)に移動します。
2.  Terraformが作成した `TWILIO_ACCOUNT_SID` と `TWILIO_AUTH_TOKEN` という名前のシークレットがそれぞれ存在します。
3.  各シークレットを選択し、「新しいバージョンの追加」から、ご自身のTwilioアカウント情報を**シークレットの値**として入力・保存します。

**その他の環境変数について:**
`APP_USER`, `APP_PASSWORD`, `FROM_PHONE_NUMBER`, `TO_PHONE_NUMBER` については、Cloud Runサービスのコンソール画面から直接環境変数として設定するか、同様にSecret Managerで管理し、`terraform/main.tf`を編集してコンテナに渡すようにしてください。

### ステップ5: デプロイの実行

`main`ブランチにコミットをプッシュすると、自動的にGitHub Actionsのワークフローが開始されます。
Actionsの実行ログで、ビルドとデプロイの進捗を確認できます。

デプロイが成功すると、Cloud RunサービスのURLが発行され、アプリケーションが利用可能になります。

## アプリケーションのトリガー方法

Cloud Runから提供されるHTTPS URLに対して、Basic認証情報と共にGETまたはPOSTリクエストを送信することで、電話発信が開始されます。

```bash
curl -u "your_username:your_password" https://your-cloud-run-service-url/
```

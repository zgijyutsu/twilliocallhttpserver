
# Terraform と Google Cloud Provider のバージョンを指定
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

# Google Cloud Provider の設定
provider "google" {
  project = var.project_id
  region  = var.region
}

# 変数の定義
variable "project_id" {
  description = "Google CloudプロジェクトID"
  type        = string
}

variable "region" {
  description = "リソースをデプロイするリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "service_name" {
  description = "Cloud Runサービスの名称"
  type        = string
  default     = "twilio-call-server"
}

variable "artifact_repository" {
  description = "Artifact Registryのリポジトリ名"
  type        = string
  default     = "cloud-run-source-deploy"
}

# --- リソースの定義 ---

# 1. Artifact Registry (Dockerイメージ保存先)
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.artifact_repository
  format        = "DOCKER"
  description   = "Repository for Cloud Run Docker images"
}

# 2. Secret Manager (TwilioのトークンとSID用)
resource "google_secret_manager_secret" "twilio_auth_token" {
  secret_id = "TWILIO_AUTH_TOKEN"
  replication {
    automatic = true
  }
  # Note: シークレットの値は手動またはCI/CDで設定します
}

resource "google_secret_manager_secret" "twilio_account_sid" {
  secret_id = "TWILIO_ACCOUNT_SID"
  replication {
    automatic = true
  }
}

# 3. Cloud Run サービス
resource "google_cloud_run_v2_service" "twilio_service" {
  name     = var.service_name
  location = var.region

  # トラフィックの100%を最新のリビジョンにルーティング
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  template {
    # コンテナの設定
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repository}/${var.service_name}:latest" # 初回デプロイ時はダミーイメージでも可

      # Secret Managerから環境変数として注入
      env {
        name = "TWILIO_AUTH_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.twilio_auth_token.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "TWILIO_ACCOUNT_SID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.twilio_account_sid.secret_id
            version = "latest"
          }
        }
      }
      # その他の環境変数はCloud Runのコンソールまたはgcloudコマンドで設定することを推奨
      # (APP_USER, APP_PASSWORD, FROM_PHONE_NUMBER, TO_PHONE_NUMBER)
    }

    # スケーリング設定 (例)
    scaling {
      min_instance_count = 0 # アイドル時には0にスケールダウン
      max_instance_count = 2 # 最大2インスタンスまで
    }
  }
}

# 4. Cloud Runを誰でも呼び出せるようにするIAM設定 (Twilio Webhookなど)
resource "google_cloud_run_v2_service_iam_member" "noauth" {
  location = google_cloud_run_v2_service.twilio_service.location
  name     = google_cloud_run_v2_service.twilio_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}


# --- Workload Identity Federation (GitHub Actions用) ---

# Workload Identity Pool の作成
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions"
}

# Workload Identity Pool Provider の作成
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions Provider"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  # GitHubリポジトリを指定 (例: "your-github-org/your-repo-name")
  # `attribute.repository` を使って特定のリポジトリに限定することが推奨されます
  # attribute_condition = "attribute.repository == 'my-org/my-repo'"
}

# GitHub Actionsが使用するサービスアカウント
resource "google_service_account" "github_actions_sa" {
  account_id   = "github-actions-runner"
  display_name = "GitHub Actions Service Account"
}

# サービスアカウントに必要なロールを付与
# 1. Cloud Runへのデプロイ権限
resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

# 2. Artifact Registryへの書き込み権限
resource "google_project_iam_member" "artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

# 3. サービスアカウントがCloud Runサービスを起動する際のIAMユーザー権限
resource "google_project_iam_member" "iam_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}


# WIFとサービスアカウントを紐付ける
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_actions_sa.name
  role               = "roles/iam.workloadIdentityUser"
  # 特定のGitHubリポジトリやブランチに絞ることを強く推奨
  # 例: "principalSet://iam.googleapis.com/{pool_id}/attribute.repository/{owner}/{repo}"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/your-github-org/your-repo-name"
}

# --- 出力 ---
output "cloud_run_service_url" {
  description = "The URL of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.twilio_service.uri
}

output "workload_identity_provider" {
  description = "The Workload Identity Provider for GitHub Actions."
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "service_account_email" {
  description = "The email of the service account for GitHub Actions."
  value       = google_service_account.github_actions_sa.email
}

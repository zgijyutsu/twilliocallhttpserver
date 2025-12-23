# アプリケーション認証情報
resource "google_secret_manager_secret" "app_user" {
  secret_id = "APP_USER"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "app_password" {
  secret_id = "APP_PASSWORD"
  replication {
    automatic = true
  }
}

# Twilio 電話番号
resource "google_secret_manager_secret" "from_phone_number" {
  secret_id = "FROM_PHONE_NUMBER"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "to_phone_number" {
  secret_id = "TO_PHONE_NUMBER"
  replication {
    automatic = true
  }
}

# Twilio 認証情報
resource "google_secret_manager_secret" "twilio_account_sid" {
  secret_id = "TWILIO_ACCOUNT_SID"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "twilio_auth_token" {
  secret_id = "TWILIO_AUTH_TOKEN"
  replication {
    automatic = true
  }
}

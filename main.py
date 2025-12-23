import os
from flask import Flask, request, Response
from twilio.rest import Client

app = Flask(__name__)

# 認証チェックを行う関数
def check_auth(username, password):
    env_user = os.environ.get("APP_USER")
    env_password = os.environ.get("APP_PASSWORD")
    # 環境変数が設定されていない場合の安全策
    if not env_user or not env_password:
        return False
    return username == env_user and password == env_password

# 認証失敗時のレスポンスを返す関数
def authenticate():
    return Response(
        'Could not verify your access level for that URL.\n'
        'You have to login with proper credentials', 401,
        {'WWW-Authenticate': 'Basic realm="Login Required"'})

@app.route("/", methods=["GET", "POST"])
def make_call():
    # --- ここから認証チェック ---
    auth = request.authorization
    if not auth or not check_auth(auth.username, auth.password):
        return authenticate()
    # ------------------------

    # 環境変数の取得
    account_sid = os.environ.get("TWILIO_ACCOUNT_SID")
    auth_token = os.environ.get("TWILIO_AUTH_TOKEN")
    from_number = os.environ.get("FROM_PHONE_NUMBER")
    
    # 宛先番号を文字列として取得
    to_numbers_str = os.environ.get("TO_PHONE_NUMBER", "")

    if not all([account_sid, auth_token, from_number, to_numbers_str]):
        return "Error: 必要な環境変数が設定されていません", 500

    # 【変更点1】カンマ区切りで分割し、空白を除去してリスト化する
    # 例: "+8190..., +8180..." -> ["+8190...", "+8180..."]
    to_numbers = [num.strip() for num in to_numbers_str.split(',') if num.strip()]

    if not to_numbers:
        return "Error: 有効な宛先電話番号が見つかりません", 500

    results = [] # 結果を格納するリスト

    try:
        client = Client(account_sid, auth_token)

        # 【変更点2】リストの数だけループして発信処理を行う
        for number in to_numbers:
            try:
                call = client.calls.create(
                    url="https://handler.twilio.com/twiml/EHd272a164b7aa523fbf551a6792b4d692",
                    to=number,
                    from_=from_number
                )
                results.append(f"[Success] {number}: {call.sid}")
            except Exception as call_error:
                # 1件失敗しても他は止まらないように個別にキャッチする
                results.append(f"[Error] {number}: {str(call_error)}")

        # 全ての結果を改行でつないで返す
        return "\n".join(results), 200

    except Exception as e:
        return f"System Error: {str(e)}", 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(debug=True, host="0.0.0.0", port=port)
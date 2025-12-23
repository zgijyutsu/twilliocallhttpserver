# Python 3.11 の軽量版ベースイメージを使用
FROM python:3.11-slim

# 作業ディレクトリを作成
WORKDIR /app

# 先にライブラリ一覧をコピーしてインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# プログラム本体をコピー
COPY main.py .

# Webサーバー(Gunicorn)として起動するコマンド
# Cloud RunはPORT環境変数でポートを指定するため、それに合わせる
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 main:app

#!/bin/bash

set -e

# APIキーを直接スクリプトに埋め込む
OPENAI_API_KEY="sk-XXXXXXXXXXXXXXXXXXXX"
GOOGLE_API_KEY="abc-XXXXXXXXXXXXXXXXXXXX"
FLASK_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(16))")

echo "[1/5] パッケージ更新＆必要ソフトのインストール"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git python3 python3-venv python3-pip nginx

echo "[2/5] Flaskアプリの取得とセットアップ"
cd /home/ryu
mkdir -p roleplay-chatbot
cd roleplay-chatbot
git clone https://github.com/CaCC-Lab/roleplay-chatbot-wepapp.git
cd roleplay-chatbot-wepapp
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn python-dotenv

echo "[3/5] .envファイルの作成"
cat > /home/ryu/roleplay-chatbot/roleplay-chatbot-wepapp/.env << EOF
OPENAI_API_KEY=${OPENAI_API_KEY}
GOOGLE_API_KEY=${GOOGLE_API_KEY}
FLASK_SECRET_KEY=${FLASK_SECRET_KEY}
EOF

echo "[4/5] Gunicornサービスの登録"
sudo tee /etc/systemd/system/roleplay-gunicorn.service > /dev/null << EOF
[Unit]
Description=Gunicorn instance to serve roleplay-chatbot-webapp
After=network.target

[Service]
User=ryu
WorkingDirectory=/home/ryu/roleplay-chatbot/roleplay-chatbot-wepapp
ExecStart=/home/ryu/roleplay-chatbot/roleplay-chatbot-wepapp/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8001 roleplay-chatbot-wepapp-main:app

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable roleplay-gunicorn
sudo systemctl start roleplay-gunicorn

echo "[5/5] Nginxの設定と起動"
sudo tee /etc/nginx/sites-available/roleplay > /dev/null << EOF
server {
    listen 81;
    server_name _;

    location / {
        proxy_pass http://localhost:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/roleplay /etc/nginx/sites-enabled/
sudo systemctl restart nginx

echo "=== デプロイ完了！ http://<Azure VMのパブリックIP>:81 にアクセスしてください ==="
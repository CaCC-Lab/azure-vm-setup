#!/bin/bash

set -e

echo "[1/5] パッケージ更新＆必要ソフトのインストール"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git python3 python3-venv python3-pip nginx

echo "[2/5] Ollamaのインストール"
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl enable ollama
sudo systemctl start ollama

echo "[3/5] Flaskアプリの取得とセットアップ"
cd /home/ryu
git clone https://github.com/CaCC-Lab/flask-ollama-chat.git
cd flask-ollama-chat
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn

echo "[4/5] Gunicornサービスの登録"
sudo tee /etc/systemd/system/gunicorn.service > /dev/null << EOF
[Unit]
Description=Gunicorn instance to serve flask-ollama-chat
After=network.target

[Service]
User=ryu
Group=www-data
WorkingDirectory=/home/ryu/flask-ollama-chat
ExecStart=/home/ryu/flask-ollama-chat/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 app:app

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl start gunicorn

echo "[5/5] Nginxの設定と起動"
sudo rm -f /etc/nginx/sites-enabled/default
sudo tee /etc/nginx/sites-available/flask > /dev/null << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/flask /etc/nginx/sites-enabled/
sudo systemctl restart nginx

echo "=== 完了！ http://<Azure VMのパブリックIP> にアクセスしてください ==="
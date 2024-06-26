#!/bin/bash
# 增加swap空间
sudo mkdir /swap
sudo fallocate -l 24G /swap/swapfile
sudo chmod 600 /swap/swapfile
sudo mkswap /swap/swapfile
sudo swapon /swap/swapfile
echo '/swap/swapfile swap swap defaults 0 0' >> /etc/fstab
echo "增加网络带宽"
sudo bash -c 'cat >> /etc/sysctl.conf <<EOF
net.core.rmem_max=600000000
net.core.wmem_max=600000000
EOF'
sudo sysctl -p

echo "安装docker"
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt-cache policy docker-ce
sudo apt install -y docker-ce

# 克隆源代码
cat > ~/docker-compose.yml <<EOF
services:
  watchtower:
    image: containrrr/watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_POLL_INTERVAL=900
      - WATCHTOWER_SCOPE=quilibrium
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
  node:
    image: byfish/ceremonyclient
    restart: always
    labels:
      - "com.centurylinklabs.watchtower.scope=quilibrium"
    deploy:
      resources:
        limits:
          memory: "32G"
        reservations:
          cpus: "12"
          memory: "16G"
    environment:
      - DEFAULT_LISTEN_GRPC_MULTIADDR=/ip4/0.0.0.0/tcp/8337
      - DEFAULT_LISTEN_REST_MULTIADDR=/ip4/0.0.0.0/tcp/8338
      - DEFAULT_STATS_MULTIADDR=/dns/stats.quilibrium.com/tcp/443
    ports:
      - '8336:8336/udp' # p2p
      - '8337:8337/tcp' # gRPC
      - '8338:8338/tcp' # REST
    healthcheck:
      test: ["CMD", "node", "--peer-id"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 1m
    volumes:
      - ./.config:/root/.config
    logging:
      driver: "json-file"
      options:
        max-file: "5"
        max-size: 2048m
EOF

echo "启动节点"
sudo docker compose up -d

# 开启端口
echo "开启端口"
sudo ufw allow 22
sudo ufw allow 443
sudo ufw allow 8337
sudo ufw allow 8338

sudo docker ps

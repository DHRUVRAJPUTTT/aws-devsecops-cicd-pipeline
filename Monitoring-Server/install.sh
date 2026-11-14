
#!/bin/bash

set -euo pipefail

# ==========================================
# Update System
# ==========================================

echo "Updating system packages..."

apt-get update -y
apt-get install -y wget curl tar gpg apt-transport-https software-properties-common

# ==========================================
# Install Prometheus
# ==========================================

echo "Installing Prometheus..."

PROMETHEUS_VERSION="2.47.1"

if ! id prometheus >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin prometheus
fi

cd /tmp

wget -q -O prometheus.tar.gz \
    "https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz"

tar -xzf prometheus.tar.gz

cd "prometheus-$PROMETHEUS_VERSION.linux-amd64"

mkdir -p /etc/prometheus
mkdir -p /data/prometheus

install -m 0755 prometheus /usr/local/bin/prometheus
install -m 0755 promtool /usr/local/bin/promtool

cp -r consoles /etc/prometheus/
cp -r console_libraries /etc/prometheus/
cp prometheus.yml /etc/prometheus/prometheus.yml

chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /data/prometheus

cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s

ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/data/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

# ==========================================
# Install Node Exporter
# ==========================================

echo "Installing Node Exporter..."

NODE_EXPORTER_VERSION="1.6.1"

if ! id node_exporter >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter
fi

cd /tmp

wget -q -O node_exporter.tar.gz \
    "https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz"

tar -xzf node_exporter.tar.gz

install -m 0755 \
    "node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter" \
    /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s

ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
EOF

# ==========================================
# Install Grafana
# ==========================================

echo "Installing Grafana..."

mkdir -p /etc/apt/keyrings

wget -q -O - https://apt.grafana.com/gpg.key | \
    gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg

chmod 644 /etc/apt/keyrings/grafana.gpg

echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    > /etc/apt/sources.list.d/grafana.list

apt-get update -y
apt-get install -y grafana

# ==========================================
# Enable and Start Services
# ==========================================

echo "Starting monitoring services..."

systemctl daemon-reload

systemctl enable prometheus
systemctl enable node_exporter
systemctl enable grafana-server

systemctl restart prometheus
systemctl restart node_exporter
systemctl restart grafana-server

# ==========================================
# Cleanup
# ==========================================

echo "Cleaning temporary installation files..."

rm -rf /tmp/prometheus.tar.gz
rm -rf /tmp/node_exporter.tar.gz
rm -rf /tmp/prometheus-$PROMETHEUS_VERSION.linux-amd64
rm -rf /tmp/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64

# ==========================================
# Verify Installation
# ==========================================

echo "Checking monitoring services..."

systemctl is-active prometheus
systemctl is-active node_exporter
systemctl is-active grafana-server

echo "=========================================="
echo "Monitoring Stack Installation Completed!"
echo "=========================================="

echo "Prometheus:    http://SERVER_PUBLIC_IP:9090"
echo "Node Exporter: http://SERVER_PUBLIC_IP:9100/metrics"
echo "Grafana:       http://SERVER_PUBLIC_IP:3000"

echo "Grafana username: admin"
echo "Change the default Grafana password after login."

# home-infrastructure

自宅クラウド用kubenix config

## 準備

```bash
export NODE_IP=192.168.1.10
```

## 初回構築

```bash
# maintenance modeで
talosctl get disks --insecure --nodes $NODE_IP

# secretの生成
talosctl gen secrets -o secrets.yaml

talosctl gen config my-cluster https://$NODE_IP:6443 --with-secrets secrets.yaml --install-disk /dev/sda --config-patch patch.yaml

talosctl apply-config --insecure --nodes $NODE_IP --file controlplane.yaml
rm controlplane.yaml worker.yaml

talosctl config endpoints $NODE_IP
talosctl config nodes $NODE_IP
talosctl bootstrap # 初回のみ

talosctl kubeconfig ./kubeconfig
kubectl get nodes
```

## Kubernetes リソースの適用

```bash
nix build .#infra -o out-infra
kubectl apply --server-side -f out-infra

nix build .#apps -o out-apps
kubectl apply -f out-apps
```

## Talos 設定の変更 (2回目以降)

```bash
talosctl gen config my-cluster https://$NODE_IP:6443 --with-secrets secrets.yaml --install-disk /dev/sda --config-patch patch.yaml --output-types controlplane -o controlplane.yaml --force
talosctl apply-config --nodes $NODE_IP --file controlplane.yaml
rm controlplane.yaml
```

## 各種configの取得

talosconfig:
```bash
talosctl gen config my-cluster https://$NODE_IP:6443 --with-secrets secrets.yaml --output-types talosconfig -o talosconfig --force
```

kubeconfig:
```bash
talosctl kubeconfig ./kubeconfig
```

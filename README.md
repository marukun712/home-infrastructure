# home-infrastructure

自宅クラウド用kubenix config

## 準備

```bash
export NODE_IP=hoge
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

export KUBECONFIG=./kubeconfig
kubectl get nodes
```

## Kubernetes リソースの適用

ビルド

```bash
./build.sh
```

シークレットを作っていない場合は作る

```bash
kubectl -n monitoring create secret generic grafana-admin --from-literal=admin-user=admin --from-literal=admin-password=
kubectl -n immich create secret generic immich-db --from-literal=password=
kubectl -n netbird create secret generic netbird-mgmt-api-key --from-literal=NB_API_KEY=$(cat netbird-pat)
```

```bash
kubectl apply -f out/<service>
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

## NetBirdのデプロイ

netbird/inventory.iniでNetBirdをインストールするサーバーのIPを指定

```ini
[netbird]
160.236.116.20 ansible_user=mni-user
```

インストールする

```bash
cd netbird
sh update.sh
```

## NetBird Operator のデプロイ

PATをnetbird-patに保存して実行

```bash
sh tf.sh plan
sh tf.sh apply
```

## アクセスできるサービス

| サービス         | URL                                                    | Service           | Namespace  |
| ---------------- | ------------------------------------------------------ | ----------------- | ---------- |
| Grafana          | http://grafana.monitoring.syakechan.internal           | grafana           | monitoring |
| Prometheus       | http://prometheus-server.monitoring.syakechan.internal | prometheus-server | monitoring |
| Immich           | http://immich-server.immich.syakechan.internal:2283    | immich-server     | immich     |
| Kubernetes API   | https://kubernetes.default.syakechan.internal          | kubernetes        | default    |
| NetBird 管理画面 | https://netbird.maril.blue                             | -                 | -          |

公開するサービスを増やすときはk8s/netbird.nixにNetworkResourceを追加する

### kubectlの設定

```bash
kubectl config set-cluster my-cluster --server=https://kubernetes.default.syakechan.internal
kubectl config set-cluster my-cluster --tls-server-name=kubernetes.default.svc
```

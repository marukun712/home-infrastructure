# home-infrastructure

自宅サーバーの NixOS 設定。宣言的に管理するために書いた。ちゃんと読んでから触ること。

## 構成

3つの VM に役割を分けてある。理由は分かると思うけど一応書いておく。

```
router   ... WireGuard + NAT + DHCP。外との窓口はここだけ。
photo    ... Immich + Samba。データは /mnt/data にマウントした別ディスクに置く。
services ... n-high-lovelive。それだけ。
```

ネットワークの全体像はこう。

```
Internet
    |
  F660P (192.168.1.x)
    |  WiFi
  PVE ホスト
    |
  router VM (192.168.10.1)  <-- WireGuard の入口はここだけ
    |
  192.168.10.0/24
    |-- photo VM    (DHCP で取得)
    `-- services VM (DHCP で取得)
```

外部からの入口は WireGuard の UDP 51820 のみ。それ以外は閉じてある。

## イメージのビルド

```bash
# それぞれ個別にビルドする
nixos-rebuild build-image --image-variant proxmox --flake .#router
nixos-rebuild build-image --image-variant proxmox --flake .#photo
nixos-rebuild build-image --image-variant proxmox --flake .#services
```

ビルドが終わると `result/` に成果物が入る。

```bash
ls result/
# nixos.vma.zst が入ってるはず
```

**PVE へのアップロード**

```bash
# PVE ホストに転送
scp result/nixos.vma.zst root@<PVEのIP>:/tmp/

# PVE ホストで VM として復元 (VMID は空いてる番号を指定)
qmrestore /tmp/nixos.vma.zst <VMID>
```

**PVE のブリッジ設定を忘れずに。** router の eth1 と photo・services の eth0 を同じブリッジに繋ぐこと。

## 初回セットアップ

### WireGuard 鍵の生成

router VM に入って実行する。

```bash
wg genkey | tee /etc/wireguard/private | wg pubkey
```

公開鍵をクライアント側に渡して、`router.nix` の `peers` に追加する。

```nix
networking.wireguard.interfaces.wg0.peers = [
  {
    publicKey = "クライアントの公開鍵";
    allowedIPs = [ "10.0.0.2/32" ];
  }
];
```

追加したら `nixos-rebuild switch --flake .#router` で反映。

### Samba のパスワード設定

Samba のパスワードだけは宣言的に設定できない。photo VM に入って1回だけ実行すること。

```bash
smbpasswd -a maril
```

## 設定を変えるとき

基本は該当の `.nix` ファイルを編集して `nixos-rebuild switch` するだけ。

VM を完全に作り直す場合は `build-image` → PVE にインポートし直す。
photo VM を作り直すときはデータディスク (`/mnt/data`) を忘れずにアタッチすること。データは OS ディスクに置いていない。

## メモ

- F660P のファイアウォールは `低` にしてある。`off` にしない。IoT が死ぬ。
- SNTP は `ntp.nict.jp`、3600 秒間隔。
- 内部ネットワーク (`192.168.10.x`) のアドレス体系は何でもよかったけど F660P の `192.168.1.x` と被らないようにこれにした。

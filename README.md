# home-infrastructure

自宅サーバーの NixOS 設定。勝手に変えないこと。わからないことがあれば聞いて。

**管理者: 麻布麻衣**

## 構成

```
Internet
    |
  F660P (ゲートウェイ)
    | 有線 (enp4s0, DHCP)
  NixOS "ria"
  nftables
    |
    +-- wg0 (10.0.0.1/24)  WireGuard
    |     +-- aiha (nixos-develop)   10.0.0.2
    |     +-- honon (bazzite-os)     10.0.0.3
    |     +-- rina (iphone)          10.0.0.4
    |     +-- seri (oppo-pad-air)    10.0.0.5
    |
    +-- wlp2s0 (192.168.10.1/24)  WiFi AP
          +-- 家族スマホ、IoT 等
```

外から開けてるのは WireGuard (UDP 51820) と Caddy (TCP 80/443) だけ。それ以外は全部閉じてある。
Immich と Samba は VPN に繋いでから `10.0.0.1` を叩くこと。直接外には出さない。

## ファイル構成

```
flake.nix    全体のエントリーポイント。disko と server を束ねる。
disko.nix    /dev/sda のパーティション設定 (GPT + EFI 512M + ext4)
server.nix   設定の本体。ネットワーク・WiFi AP・WireGuard・全サービスここ。
install.sh   インストールスクリプト
```

## インストール

NixOS の minimal ISO で起動して実行する。

```bash
git clone https://github.com/marukun712/home-infrastructure
cd home-infrastructure
bash install.sh
```

disko でパーティションを切って、そのまま nixos-install を流す。

## 初回セットアップ

### WireGuard 鍵の生成

サーバーに入って実行する。

```bash
wg genkey | tee /etc/wireguard/private | wg pubkey
```
この公開鍵は、クライアント側で登録する。

### WiFi AP のパスワード

hostapd のパスワードは config に書かずファイルで管理する。1回だけ手動で作成すること。

```bash
mkdir -p /etc/hostapd
echo "パスワード" > /etc/hostapd/wpa_passphrase
chmod 600 /etc/hostapd/wpa_passphrase
```

### Grafana のシークレットキー

```bash
mkdir -p /etc/grafana
echo "シークレットキー" > /etc/grafana/private
chmod 600 /etc/grafana/private
```

### Samba のパスワード

Samba だけは宣言的に設定できない。1回だけ手動で実行すること。

```bash
smbpasswd -a maril
```

## SSH でサーバーに入る

VPN に接続してから叩く。ポート 22 は外部に開いていない。

```bash
ssh maril@10.0.0.1
```

## クライアントを追加するとき

**クライアント側で鍵ペアを生成する。**

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

**サーバー側: `server.nix` の `peers` にクライアントを追記して rebuild する。**

```nix
networking.wireguard.interfaces.wg0.peers = [
  {
    publicKey = "クライアントの公開鍵";
    allowedIPs = [ "10.0.0.x/32" ];  # 既存と被らない IP を割り当てる
  }
];
```

**クライアント側: WireGuard の設定ファイルを作る。**

```ini
[Interface]
PrivateKey = クライアントの秘密鍵
Address = 10.0.0.x/24

[Peer]
PublicKey = サーバーの公開鍵
Endpoint = サーバーのグローバル IPv6:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
```

PC なら `wg-quick up` で接続、スマホなら WireGuard アプリで QR コードか設定ファイルを読み込む。

> サーバーの公開鍵は `cat /etc/wireguard/private | wg pubkey` で確認できる。

## クライアントを削除するとき

`server.nix` の `peers` から該当エントリを消して rebuild するだけ。

```bash
nixos-rebuild switch --flake github:marukun712/home-infrastructure#server
```

## 設定を変えるとき

```bash
nixos-rebuild switch --flake github:marukun712/home-infrastructure#server
```

変更は必ず `server.nix` に書く。手動でいじらない。

## 外部公開サービスを追加するとき

`server.nix` の `services.caddy.virtualHosts` にエントリを足して `nixos-rebuild switch` するだけ。

```nix
services.caddy.virtualHosts."new-service.maril.blue".extraConfig = "reverse_proxy localhost:XXXX";
```

DNS は Cloudflare で AAAA レコードを追加してプロキシ無効にする。

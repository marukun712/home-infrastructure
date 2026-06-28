# home-infrastructure 💻

自宅サーバーの NixOS 設定。勝手に変えないこと。わからないことがあれば聞いて。

**管理者: 麻布麻衣** 🐌

## 構成

NixOS 1台にベアメタルで入れてある。コンテナで役割を分けて、余計な複雑さは持ち込まない方針。

```
Internet
    |
  F660P (ゲートウェイ。ルーター・FW の役割はサーバーが担う)
    |
  wlp2s0 (NixOS "ria", グローバル IPv6)
    |
    +-- wg0 (10.0.0.1/24)  WireGuard の入口
    |     +-- 日常PC       10.0.0.2
    |     +-- 開発PC       10.0.0.3
    |     +-- スマホ       10.0.0.4
    |     +-- photo        Immich :2283, Samba :445  (VPN経由のみ)
    |
    +-- services           lovehigh :4000  (外部公開)
```

外から開けてるのは WireGuard (UDP 51820) と Caddy (TCP 80/443) だけ。それ以外は全部閉じてある。
Immich と Samba は VPN に繋いでから `10.0.0.1` を叩くこと。直接外には出さない。

## ファイル構成 💻

```
flake.nix    全体のエントリーポイント。disko と server を束ねる。
disko.nix    /dev/sda のパーティション設定 (GPT + EFI 512M + ext4)
server.nix   設定の本体。WireGuard + コンテナ全部ここ。
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

### ネットワーク接続

WiFi の場合は `nmtui` で接続する。認証情報は NetworkManager が管理するため config には書かない。

```bash
nmtui
```

### WireGuard 鍵の生成 💻

サーバーに入って実行する。

```bash
wg genkey | tee /etc/wireguard/private | wg pubkey
```

出てきた公開鍵を `server.nix` の `peers` に追加して `nixos-rebuild switch` する。

```nix
networking.wireguard.interfaces.wg0.peers = [
  {
    publicKey = "クライアントの公開鍵";
    allowedIPs = [ "10.0.0.x/32" ];
  }
];
```

### Samba のパスワード

Samba だけは宣言的に設定できない。1回だけ手動で実行すること。

```bash
nixos-container run photo -- smbpasswd -a maril
```

### データディレクトリ 💻

photo コンテナは `/var/lib/photo` にデータを置く。HDD 1 台構成のため OS と同じパーティション上のただのディレクトリ。別途マウントは不要。

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

## 各サービスへのアクセス方法

VPN に接続してから以下を叩く。

| サービス | アクセス先 |
|---|---|
| Immich | http://10.0.0.1:2283 (データ: /var/lib/photo/immich) |
| Samba | \\\\10.0.0.1\photos (データ: /var/lib/photo/samba) |
| lovehigh | https://n-lovehigh.maril.blue (VPN 不要) |

## コンテナの操作

```bash
# コンテナの状態確認
nixos-container list

# コンテナを再起動
nixos-container restart photo
nixos-container restart services

# コンテナのシェルに入る
nixos-container root-login photo
nixos-container root-login services
```

## 設定を変えるとき

```bash
nixos-rebuild switch --flake github:marukun712/home-infrastructure#server
```

変更は必ず `server.nix` に書く。手動でいじらない。

## 外部公開サービスを追加するとき 💻

`server.nix` の `services.caddy.virtualHosts` にエントリを足して `nixos-rebuild switch` するだけ。

```nix
services.caddy.virtualHosts."new-service.maril.blue".extraConfig = "reverse_proxy localhost:XXXX";
```

DNS は Cloudflare で AAAA レコードを追加してプロキシ有効 (オレンジ雲) にする。

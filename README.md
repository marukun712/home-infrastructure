# home-infrastructure

自宅サーバーの NixOS 設定。触る前にちゃんと読むこと。

## 構成

サーバーマシン 1台に NixOS をベアメタルで入れて、コンテナで役割を分けてある。
PVE は使わない。全部 Nix で書く。

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

コンテナはホストのネットワークをそのまま使う。余計な IP 体系は増やさない。
外から届くのは UDP 51820 (WireGuard) と TCP 80/443 (Caddy) だけ。
Caddy がサブドメインでサービスにルーティングする。Immich と Samba は VPN に繋いでから `10.0.0.1` を叩く。

## ファイル構成

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

### WireGuard 鍵の生成

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

### データディスク

photo コンテナは `/mnt/data` にデータを置く。
OS とは別のディスクをマウントしておくこと。これをやらないと VM 再構築のたびにデータが消える。

## 設定を変えるとき

```bash
nixos-rebuild switch --flake github:marukun712/home-infrastructure#server
```

## 外部公開サービスを追加するとき

`server.nix` の `services.caddy.virtualHosts` にエントリを足して `nixos-rebuild switch` するだけ。

```nix
services.caddy.virtualHosts."new-service.maril.blue".extraConfig = "reverse_proxy localhost:XXXX";
```

DNS は Cloudflare で AAAA レコードを追加してプロキシ有効 (オレンジ雲) にする。

## F660P について

今は有線 LAN がないため、やむなく F660P のファイアウォールを使っている。
IPv6 パケットフィルターで以下を許可しておくこと。

- UDP 51820 (WireGuard)
- TCP 80, 443 (Caddy)

有線 LAN が来たらファイアウォールを off にしてルーター機能をサーバーに完全移管する。
それまでの暫定対応。

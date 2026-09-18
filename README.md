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
  nftables で全制御
    |
    +-- wg0 (10.0.0.1/24)  WireGuard (自分のデバイス)
    |     +-- aiha (nixos-develop)   10.0.0.2
    |     +-- honon (bazzite-os)     10.0.0.3
    |     +-- rina (iphone)          10.0.0.4
    |     +-- seri (oppo-pad-air)    10.0.0.5
    |
    +-- wg1 (10.0.10.1/24)  WireGuard (友人間 VPN)
    |     +-- aiha (nixos-develop)   10.0.10.2
    |     +-- akaz                   10.0.10.3
    |     +-- tmak                   10.0.10.4
    |     +-- ryouma                 10.0.10.5
    |
    +-- wg-relay (10.0.20.1/24)  WireGuard (VPS Relay)
    |     +-- VPS                    10.0.20.2
    |
    +-- wlp2s0 (192.168.10.1/24)  WiFi AP "何それ？知らん！LAN！"
          +-- 家族スマホ、IoT 等
          DHCP: 192.168.10.10 - 192.168.10.100 (kea)
          IPv6: fd00::/64 (radvd)
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

## 設定を変えるとき

```bash
nixos-rebuild switch --flake github:marukun712/home-infrastructure#server
```

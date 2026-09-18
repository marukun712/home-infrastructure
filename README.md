# home-infrastructure

自宅サーバーの NixOS 設定。勝手に変えないこと。わからないことがあれば聞いて。

**管理者: 麻布麻衣**

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

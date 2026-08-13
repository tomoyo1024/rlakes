# rlakes: NixOS + Flakes + sops-nix 入門ガイド

[English](README.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [日本語](README_ja.md)

このプロジェクトは、**NixOS**、**Flakes**、および **sops-nix** を使用してシステム設定を構築および管理する方法を実演・学習するためのプロジェクトです。
このプロジェクトを通じて、複数マシンのシステム設定やハードウェア構成を宣言的（Declarative）に管理する方法、および機密データ（Secrets）を安全に処理する方法を学ぶことができます。

## コア技術スタック

本プロジェクトは、Nixエコシステムにおける以下の強力でモダンなツールを統合しています：

- **[NixOS & Flakes](https://nixos.wiki/wiki/Flakes)**：コアシステムとパッケージ管理。完全に再現可能なシステムビルドを実現します。
- **[sops-nix](https://github.com/Mic92/sops-nix)**：Mozilla SOPSと統合し、Nixシステム内で機密ファイル（パスワードやAPIトークンなど）を安全に暗号化および管理します。
- **[disko](https://github.com/nix-community/disko)**：宣言的なディスクパーティショニングおよびフォーマットツール。
- **[nixos-facter](https://github.com/numtide/nixos-facter)**：ハードウェア情報レポート（`facter.json`）を生成し、従来の `hardware-configuration.nix` を手動で記述する手間を省きます。
- **[nixos-anywhere](https://github.com/nix-community/nixos-anywhere)**：SSH経由で任意のリモートマシンにNixOSを全自動インストールします。
- **[deploy-rs](https://github.com/serokell/deploy-rs)**：柔軟なNixOSリモートデプロイツール。Flake設定をビルドし、リモートサーバーにプッシュします。
- **[just](https://github.com/casey/just)**：コマンドランナー。プロジェクトでよく使われる複雑なコマンドをカプセル化しています。

## プロジェクト構成

- `flake.nix`：システム設定全体のエントリーポイント。`nixpkgs`の依存関係、`init`、`blinker`、`poach` などの複数マシンのシステム設定、および `deploy-rs` のデプロイメントノードを定義します。
- `sops.nix`：`sops-nix` 関連の設定モジュール。マシンのローカルにあるSSH Host Keyを使用して機密データを復号化する方法を指定します。
- `.sops.yaml`：SOPSの設定ファイル。暗号化キー（Age Keys）および特定ファイルに対する暗号化ルールを定義します。
- `secrets.yaml`：SOPS経由で暗号化された機密ファイル（例：Cloudflare API Tokenなど）。
- `justfile`：コンパイル、マシンの初期化、更新のプッシュなどの自動化スクリプトコマンドを保存します。
- `facter.json` / `poach/facter.json`：`nixos-facter` によって生成されたハードウェア設定レポート。
- `blinker/`, `poach/`, `templates/`：各ノード（マシン）やテンプレートの特定のNixOS設定ファイルが格納されているディレクトリ。

## 始め方

### 1. 準備

本プロジェクトは、ホストマシンの実行環境が NixOS であることを限定しません。ホストマシンに **Nix パッケージマネージャー**（Flakes が有効な状態）と **just** ツールがインストールされていれば十分です。ご使用のOSやディストリビューションの標準的な方法に従って、それらをインストールしてください。

Nix については、`~/.config/nix/nix.conf` に以下の設定を追加し、Flakes サポートを有効にしてください：
```ini
experimental-features = nix-command flakes
```

*注：以降の手順では、`mkpasswd`、`ssh-to-age`、`age-keygen`、`sops` などのコマンドを使用します。パッケージマネージャー等を介して、お使いのシステムにこれらのツールがインストールされていることを確認してください。*

### 2. ユーザー認証の設定（必須）

> **⚠️ 重要**: 提供されているテンプレート設定（`templates/minimal/configuration.nix` および `blinker/configuration.nix`）では、デフォルトでユーザーの `hashedPassword` と `openssh.authorizedKeys.keys` が空文字列 `""` に設定されています。デプロイする前に、**必ず**ご自身の値を生成して入力してください。

1. **ハッシュ化されたパスワードの生成**:
   `mkpasswd` を使用して安全なパスワードハッシュを生成します。
   ```bash
   mkpasswd -m sha-512
   ```
   *生成されたハッシュをコピーし、`configuration.nix` の `hashedPassword` フィールドに貼り付けてください。*

2. **SSH公開鍵の設定**:
   SSHキーペア（例: `ssh-keygen -t ed25519`）を生成していることを確認してください。公開鍵（通常は `~/.ssh/id_ed25519.pub`）の内容をコピーし、`openssh.authorizedKeys.keys` リストに追加してください。

### 3. フェーズ1：新規マシンの初期化（nixos-anywhere）

`just` スクリプトを使用して、クリック一つで `init` テンプレート設定を真新しいサーバーにインストールできます。
`<ターゲットマシンのIP>` を実際のIPアドレスに置き換えてください。自動的に `root` でログインします：

```bash
just nixos-anywhere <ターゲットマシンのIP>
```
このコマンドの裏では `nixos-anywhere` が呼び出され、`nixos-facter` と組み合わせてターゲットマシンのハードウェア構成を動的に生成し、`disko` を使ってディスクパーティショニングを行うことで「ワンクリックインストール」を実現します。インストールが完了すると、マシンは自動的に再起動し、専用のSSH Host Keyを生成します。

### 4. フェーズ2：機密データ管理の設定（sops-nix）

マシンの基本インストールが完了した後、そのマシン専用のシステム設定と機密データを設定します。このプロジェクトでは、`sops-nix` の暗号化バックエンドとして [Age](https://age-encryption.org/) を使用します。

> **⚠️ 警告**：
> プロジェクトディレクトリ内の `key.txt` は**デモおよびテスト専用**です。実際の環境では、秘密鍵を含むファイルをバージョン管理システム（Git）にコミットすることは**絶対にやめてください**！秘密鍵は安全なローカルディレクトリ（例：`~/.config/sops/age/keys.txt`）に適切に保管してください。

[Michael Stapelbergのこの記事](https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/) にあるベストプラクティスを参考にすることを強くお勧めします。既存のSSH鍵からAge鍵を直接派生させます：

1. **個人のSSH秘密鍵から管理者のAge鍵を生成する**：
   `ssh-to-age` を使用してSSH秘密鍵をAge秘密鍵に変換し、SOPSがデフォルトで読み込む場所に保存します。
   ```bash
   mkdir -p ~/.config/sops/age/
   ssh-to-age -private-key -i ~/.ssh/id_ed25519 -o ~/.config/sops/age/keys.txt
   ```
   *その後、`age-keygen -y ~/.config/sops/age/keys.txt` を実行して、この秘密鍵に対応する Age 公開鍵（Recipient）を取得し、後で設定に追加できるようにします。*

2. **インストールしたばかりのサーバーのAge公開鍵を取得する**：
   インストールしたばかりのマシンのSSH Host公開鍵を直接読み取り、Age公開鍵に変換します：
   ```bash
   ssh nixos@<ターゲットマシンのIP> cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
   ```

3. **SOPSの暗号化ルールを更新する (`.sops.yaml`)**：
   上記の手順で取得した「管理者（あなた）のAge公開鍵」と「サーバーのAge公開鍵」を `.sops.yaml` の `keys` ブロックに追加し、機密ファイルがこの2つの公開鍵で同時に暗号化されるように `creation_rules` を調整します。これにより、ローカルで復号化して編集でき、サーバーも実行時に復号化して読み取ることができるようになります。

4. **機密データの編集**：
   秘密鍵を `~/.config/sops/age/keys.txt`（SOPSのデフォルトの読み取りパス）に保存してあるため、暗号化された機密ファイルの編集は非常に簡単です：
   ```bash
   sops secrets.yaml
   ```
   編集して保存すると、SOPSは自動的に再暗号化を行います。

### 5. フェーズ3：完全なシステム設定のデプロイ（deploy-rs）

ターゲットマシンの初期化が完了し、そのマシン用の機密データ（sops）の設定も完了したら、そのマシン専用の完全な設定ファイル（例：`blinker`）をサーバーにプッシュできます：

```bash
# デフォルトでflakeをビルド
just build

# 特定のノード（例：blinker）に設定をデプロイ
just deploy blinker
```
このコマンドは `flake.nix` 内で定義された `deploy.nodes` を読み取り、ローカルでシステム設定をコンパイルした後、指定されたリモートマシンにプッシュして変更を自動的に適用（Switch）します。この時、サーバーは `sops-nix` を正しくロードし、自身のSSH Host Keyを使用して必要なデータを復号化します。

## カスタマイズと拡張

このプロジェクトを基盤として独自のクラスターを管理したい場合：
- **マシンの追加**：
  1. 対応するマシンのフォルダを作成し、専用の `configuration.nix` を記述します。
  2. `nixos-facter` を使用してそのマシンの `facter.json` を取得し、プロジェクトに配置します。
  3. `flake.nix` の `nixosConfigurations` にこのマシンの定義を追加します。
  4. `deploy.nodes` ブロックにこのマシンの接続およびデプロイ設定を追加します。
- **NixOSチャネルの切り替え**：
  サンプルの `blinker` や `poach` の書き方を参考に、マシンごとに安定版チャネル（`nixpkgs`）や開発テスト版チャネル（`nixpkgs-unstable`）を柔軟に適用できます。

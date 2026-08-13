# rlakes: NixOS + Flakes + sops-nix 入門指南

[English](README.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [日本語](README_ja.md)

這是一個用於示範及教學如何使用 **NixOS**、**Flakes** 與 **sops-nix** 建構與管理系統設定的專案。
透過這個專案，您可以學習到如何以聲明式（Declarative）的方式來管理多台機器的系統設定檔、硬體組態，以及如何安全地處理機密資料（Secrets）。

## 核心技術堆疊

本專案整合了以下 Nix 生態系中強大且現代的工具：

- **[NixOS & Flakes](https://nixos.wiki/wiki/Flakes)**：核心系統與套件管理，實現完全可重現的系統建置。
- **[sops-nix](https://github.com/Mic92/sops-nix)**：結合 Mozilla SOPS，在 Nix 系統中安全地加密與管理機密檔案（如密碼、API Token 等）。
- **[disko](https://github.com/nix-community/disko)**：聲明式磁碟分割與格式化工具。
- **[nixos-facter](https://github.com/numtide/nixos-facter)**：產生硬體資訊報告（`facter.json`），免除手動撰寫傳統 `hardware-configuration.nix` 的麻煩。
- **[nixos-anywhere](https://github.com/nix-community/nixos-anywhere)**：透過 SSH 全自動將 NixOS 安裝到任意遠端機器上。
- **[deploy-rs](https://github.com/serokell/deploy-rs)**：靈活的 NixOS 遠端部署工具，負責將 Flake 配置建置並推送到遠端伺服器。
- **[just](https://github.com/casey/just)**：指令運行工具（Command Runner），封裝了專案中常用的複雜指令。

## 專案結構

- `flake.nix`：整個系統設定的進入點。定義了 `nixpkgs` 依賴，以及 `init`、`blinker`、`poach` 等多台機器的系統配置與 `deploy-rs` 部署節點。
- `sops.nix`：`sops-nix` 相關設定模組，指定如何透過機器本地的 SSH Host Key 來解密機密資料。
- `.sops.yaml`：SOPS 的設定檔，定義了加密金鑰（Age Keys）及針對特定檔案的加密規則。
- `secrets.yaml`：經由 SOPS 加密過後的機密檔案（例如：Cloudflare API Token 等）。
- `justfile`：存放自動化腳本指令，例如編譯、初始化機器或推送更新。
- `facter.json` / `poach/facter.json`：由 `nixos-facter` 產生的硬體設定報告。
- `blinker/`, `poach/`, `templates/`：各個節點（機台）及樣板的特定 NixOS 配置檔所在目錄。

## 開始使用

### 1. 準備工作

本專案並不限定主機的執行環境必須是 NixOS，只需您的主機上已安裝 **Nix 套件管理員**（並開啟 Flakes 支援）以及 **just** 工具即可。請根據您所使用的作業系統或發行版自行安裝它們。

對於 Nix，請確保在 `~/.config/nix/nix.conf` 中加入以下內容以開啟 Flakes：
```ini
experimental-features = nix-command flakes
```

*註：接下來的步驟中會使用到 `mkpasswd`、`ssh-to-age`、`age-keygen` 與 `sops` 等常用指令，請確保您的系統中已透過套件管理員安裝了這些工具。*

### 2. 使用者認證設定（必須填寫）

> **⚠️ 重要**：預設情況下，提供的範本配置（`templates/minimal/configuration.nix` 與 `blinker/configuration.nix`）中的使用者 `hashedPassword` 與 `openssh.authorizedKeys.keys` 均已被設定為空字串 `""`。在部署前，您**必須**自行產生並填入您自己的值。

1. **產生 Hashed 密碼**：
   使用 `mkpasswd` 工具產生安全的密碼雜湊值（Hash）：
   ```bash
   mkpasswd -m sha-512
   ```
   *複製產生的雜湊值，並將其貼到 `configuration.nix` 檔案中的 `hashedPassword` 欄位。*

2. **設定您的 SSH 公鑰**：
   確保您已經產生了 SSH 金鑰對（例如使用 `ssh-keygen -t ed25519`）。複製您的公鑰內容（通常為 `~/.ssh/id_ed25519.pub`）並將其加入到 `openssh.authorizedKeys.keys` 列表中。

### 3. 階段一：初始化全新機器 (nixos-anywhere)

透過 `just` 腳本，您可以一鍵將 `init` 的範本配置安裝到全新的伺服器上。
請將 `<目標機器_IP>` 替換為實際的 IP 位址，這會自動使用 `root` 登入：

```bash
just nixos-anywhere <目標機器_IP>
```
這行指令背後會呼叫 `nixos-anywhere`，結合 `nixos-facter` 動態產生目標機器的硬體組態，並透過 `disko` 進行磁碟分割，實現「一鍵裝機」。裝機完成後，機器將自動重啟並產生其專屬的 SSH Host Key。

### 4. 階段二：設定機密資料管理 (sops-nix)

機器基礎安裝完成後，接著我們才為它設定專屬的系統配置與機密資料。這個專案使用 [Age](https://age-encryption.org/) 作為 `sops-nix` 的加密後端。

> **⚠️ 警告**：
> 專案目錄下的 `key.txt` **僅供示範與測試使用**。在真實環境中，**絕對不要**將包含私鑰的檔案提交到版本控制系統（Git）中！您的私鑰應妥善保管在安全的本機目錄（例如 `~/.config/sops/age/keys.txt`）。

我們強烈建議參考 [Michael Stapelberg 的這篇文章](https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/) 中的最佳實踐——直接從您現有的 SSH 金鑰衍生 Age 金鑰：

1. **從個人 SSH 私鑰產生管理員的 Age 金鑰**：
   使用 `ssh-to-age` 將您的 SSH 私鑰轉換為 Age 私鑰，並將其保存在 SOPS 預設會讀取的位置。
   ```bash
   mkdir -p ~/.config/sops/age/
   ssh-to-age -private-key -i ~/.ssh/id_ed25519 -o ~/.config/sops/age/keys.txt
   ```
   *接著，透過 `age-keygen -y ~/.config/sops/age/keys.txt` 取得這把私鑰對應的 Age 公鑰（Recipient），以便稍後加到配置中。*

2. **取得剛剛裝好機器的伺服器 Age 公鑰**：
   直接讀取剛才安裝好之機器的 SSH Host 公鑰，並轉換為 Age 公鑰：
   ```bash
   ssh nixos@<目標機器_IP> cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
   ```

3. **更新 SOPS 加密規則 (`.sops.yaml`)**：
   將上述步驟取得的「管理員（您的）Age 公鑰」與「伺服器 Age 公鑰」加入 `.sops.yaml` 的 `keys` 區塊，並調整 `creation_rules`，確保機密檔案會同時用這兩把公鑰進行加密。這樣一來，您能在本機解密編輯，而伺服器也能在執行時解密讀取。

4. **編輯機密資料**：
   由於我們已經將私鑰存放在 `~/.config/sops/age/keys.txt` (SOPS 的預設讀取路徑)，因此編輯加密的機密檔案時變得非常簡單：
   ```bash
   sops secrets.yaml
   ```
   編輯完成存檔後，SOPS 會自動重新加密。

### 5. 階段三：部署完整系統設定 (deploy-rs)

當目標機器已完成初始化，且機密資料 (sops) 也為該機器設定完畢後，您就可以將該機器專屬的完整設定檔（例如 `blinker`）推送到伺服器上：

```bash
# 預設建置 flake
just build

# 部署配置到特定節點 (例如 blinker)
just deploy blinker
```
這個指令會讀取 `flake.nix` 內定義的 `deploy.nodes`，在本地端編譯好系統配置後，再推送到指定的遠端機器並自動套用變更 (Switch)，此時伺服器便會正確載入 `sops-nix` 並利用其 SSH Host Key 解密所需資料。

## 自訂與擴充

如果您想依據此專案為基礎來管理您自己的叢集：
- **新增機器**：
  1. 建立對應機器的資料夾，並編寫專屬的 `configuration.nix`。
  2. 透過 `nixos-facter` 取得該機器的 `facter.json` 並放入專案中。
  3. 在 `flake.nix` 的 `nixosConfigurations` 中新增這個機器的定義。
  4. 在 `deploy.nodes` 區塊加入這台機器的連線及部署設定。
- **切換 NixOS 頻道**：
  您可以參考範例中的 `blinker` 與 `poach` 的寫法，靈活地為不同機器套用穩定版頻道（`nixpkgs`）或開發測試版頻道（`nixpkgs-unstable`）。

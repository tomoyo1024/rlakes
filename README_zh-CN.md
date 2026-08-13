# rlakes: NixOS + Flakes + sops-nix 入门指南

[English](README.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [日本語](README_ja.md)

这是一个用于示范及教学如何使用 **NixOS**、**Flakes** 与 **sops-nix** 构建与管理系统配置的项目。
通过这个项目，您可以学习到如何以声明式（Declarative）的方式来管理多台机器的系统配置文件、硬件配置，以及如何安全地处理机密数据（Secrets）。

## 核心技术栈

本项目整合了以下 Nix 生态系中强大且现代的工具：

- **[NixOS & Flakes](https://nixos.wiki/wiki/Flakes)**：核心系统与软件包管理，实现完全可重现的系统构建。
- **[sops-nix](https://github.com/Mic92/sops-nix)**：结合 Mozilla SOPS，在 Nix 系统中安全地加密与管理机密文件（如密码、API Token 等）。
- **[disko](https://github.com/nix-community/disko)**：声明式磁盘分区与格式化工具。
- **[nixos-facter](https://github.com/numtide/nixos-facter)**：生成硬件信息报告（`facter.json`），免除手动编写传统 `hardware-configuration.nix` 的麻烦。
- **[nixos-anywhere](https://github.com/nix-community/nixos-anywhere)**：通过 SSH 全自动将 NixOS 安装到任意远程机器上。
- **[deploy-rs](https://github.com/serokell/deploy-rs)**：灵活的 NixOS 远程部署工具，负责将 Flake 配置构建并推送到远程服务器。
- **[just](https://github.com/casey/just)**：命令运行工具（Command Runner），封装了项目中常用的复杂命令。

## 项目结构

- `flake.nix`：整个系统配置的入口点。定义了 `nixpkgs` 依赖，以及 `init`、`blinker`、`poach` 等多台机器的系统配置与 `deploy-rs` 部署节点。
- `sops.nix`：`sops-nix` 相关配置模块，指定如何通过机器本地的 SSH Host Key 来解密机密数据。
- `.sops.yaml`：SOPS 的配置文件，定义了加密密钥（Age Keys）及针对特定文件的加密规则。
- `secrets.yaml`：经由 SOPS 加密过后的机密文件（例如：Cloudflare API Token 等）。
- `justfile`：存放自动化脚本指令，例如编译、初始化机器或推送更新。
- `facter.json` / `poach/facter.json`：由 `nixos-facter` 生成的硬件配置报告。
- `blinker/`, `poach/`, `templates/`：各个节点（机台）及模板的特定 NixOS 配置文件所在目录。

## 开始使用

### 1. 准备工作

本项目并不限定主机的运行环境必须是 NixOS，只需您的主机上已安装 **Nix 包管理器**（并开启 Flakes 支持）以及 **just** 工具即可。请根据您所使用的操作系统或发行版自行安装它们。

对于 Nix，请确保在 `~/.config/nix/nix.conf` 中加入以下内容以开启 Flakes：
```ini
experimental-features = nix-command flakes
```

*注：接下来的步骤中会使用到 `mkpasswd`、`ssh-to-age`、`age-keygen` 和 `sops` 等常用命令，请确保您的系统中已通过包管理器安装了这些工具。*

### 2. 用户认证设置（必须填写）

> **⚠️ 重要**：默认情况下，提供的模板配置（`templates/minimal/configuration.nix` 和 `blinker/configuration.nix`）中的用户 `hashedPassword` 与 `openssh.authorizedKeys.keys` 均已被设置为空字符串 `""`。在部署前，您**必须**自行生成并填入您自己的值。

1. **生成 Hashed 密码**：
   使用 `mkpasswd` 工具生成安全的密码哈希值：
   ```bash
   mkpasswd -m sha-512
   ```
   *复制生成的哈希值，并将其粘贴到 `configuration.nix` 文件中的 `hashedPassword` 字段。*

2. **设置您的 SSH 公钥**：
   确保您已经生成了 SSH 密钥对（例如使用 `ssh-keygen -t ed25519`）。复制您的公钥内容（通常为 `~/.ssh/id_ed25519.pub`）并将其添加到 `openssh.authorizedKeys.keys` 列表中。

### 3. 阶段一：初始化全新机器 (nixos-anywhere)

通过 `just` 脚本，您可以一键将 `init` 的模板配置安装到全新的服务器上。
请将 `<目标机器_IP>` 替换为实际的 IP 地址，这会自动使用 `root` 登录：

```bash
just nixos-anywhere <目标机器_IP>
```
这行命令背后会调用 `nixos-anywhere`，结合 `nixos-facter` 动态生成目标机器的硬件配置，并通过 `disko` 进行磁盘分区，实现“一键装机”。装机完成后，机器将自动重启并生成其专属的 SSH Host Key。

### 4. 阶段二：设置机密数据管理 (sops-nix)

机器基础安装完成后，接着我们才为它设置专属的系统配置与机密数据。这个项目使用 [Age](https://age-encryption.org/) 作为 `sops-nix` 的加密后端。

> **⚠️ 警告**：
> 项目目录下的 `key.txt` **仅供示范与测试使用**。在真实环境中，**绝对不要**将包含私钥的文件提交到版本控制系统（Git）中！您的私钥应妥善保管在安全的本机目录（例如 `~/.config/sops/age/keys.txt`）。

我们强烈建议参考 [Michael Stapelberg 的这篇文章](https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/) 中的最佳实践——直接从您现有的 SSH 密钥衍生 Age 密钥：

1. **从个人 SSH 私钥生成管理员的 Age 密钥**：
   使用 `ssh-to-age` 将您的 SSH 私钥转换为 Age 私钥，并将其保存在 SOPS 默认会读取的位置。
   ```bash
   mkdir -p ~/.config/sops/age/
   ssh-to-age -private-key -i ~/.ssh/id_ed25519 -o ~/.config/sops/age/keys.txt
   ```
   *接着，通过 `age-keygen -y ~/.config/sops/age/keys.txt` 获取这把私钥对应的 Age 公钥（Recipient），以便稍后加到配置中。*

2. **获取刚刚装好机器的服务器 Age 公钥**：
   直接读取刚才安装好之机器的 SSH Host 公钥，并转换为 Age 公钥：
   ```bash
   ssh nixos@<目标机器_IP> cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
   ```

3. **更新 SOPS 加密规则 (`.sops.yaml`)**：
   将上述步骤获取的“管理员（您的）Age 公钥”与“服务器 Age 公钥”加入 `.sops.yaml` 的 `keys` 区块，并调整 `creation_rules`，确保机密文件会同时用这两把公钥进行加密。这样一来，您能在本机解密编辑，而服务器也能在运行时解密读取。

4. **编辑机密数据**：
   由于我们已经将私钥存放在 `~/.config/sops/age/keys.txt` (SOPS 的默认读取路径)，因此编辑加密的机密文件时变得非常简单：
   ```bash
   sops secrets.yaml
   ```
   编辑完成存盘后，SOPS 会自动重新加密。

### 5. 阶段三：部署完整系统配置 (deploy-rs)

当目标机器已完成初始化，且机密数据 (sops) 也为该机器设置完毕后，您就可以将该机器专属的完整配置文件（例如 `blinker`）推送到服务器上：

```bash
# 默认构建 flake
just build

# 部署配置到特定节点 (例如 blinker)
just deploy blinker
```
这个命令会读取 `flake.nix` 内定义的 `deploy.nodes`，在本地端编译好系统配置后，再推送到指定的远程机器并自动应用变更 (Switch)，此时服务器便会正确加载 `sops-nix` 并利用其 SSH Host Key 解密所需数据。

## 自定义与扩展

如果您想依据此项目为基础来管理您自己的集群：
- **新增机器**：
  1. 建立对应机器的文件夹，并编写专属的 `configuration.nix`。
  2. 通过 `nixos-facter` 获取该机器的 `facter.json` 并放入项目中。
  3. 在 `flake.nix` 的 `nixosConfigurations` 中新增这个机器的定义。
  4. 在 `deploy.nodes` 区块加入这台机器的连接及部署设置。
- **切换 NixOS 频道**：
  您可以参考示例中的 `blinker` 与 `poach` 的写法，灵活地为不同机器应用稳定版频道（`nixpkgs`）或开发测试版频道（`nixpkgs-unstable`）。

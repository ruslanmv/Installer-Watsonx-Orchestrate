# ⚙️ Watsonx Orchestrate DevKit — Cross-Platform Installer

> One command to set up a full **IBM watsonx Orchestrate** dev environment on **Windows**, **WSL (Ubuntu)**, **macOS**, and **Ubuntu**.

[![Python 3.11+](https://img.shields.io/badge/Python-3.11%2B-blue)](#)
[![OS](https://img.shields.io/badge/OS-Windows%20%7C%20WSL%20\(Ubuntu\)%20%7C%20macOS%20%7C%20Ubuntu-brightgreen)](#)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue)](#license)

---

## ✨ Highlights

* 🧠 **Smart OS detection**: Windows, WSL (Ubuntu), macOS, Ubuntu
* ⚙️ **Single command**: `make install` sets up Python 3.11, Docker, a local `venv`, and the **Orchestrate ADK**
* 🐳 **Windows**: choose **Docker Desktop** or **Docker inside WSL** (engine + compose)
* 🔒 **Project-local** Python virtual environment
* 📄 **`.env`** credentials support (not committed)
* 🧭 Clean **Makefile** workflow: `install`, `start`, `run`, `stop`, `purge`, `export`, `help`

---

## 🖥️ Supported Platforms

| Platform          | How installers run                                                                         |
| ----------------- | ------------------------------------------------------------------------------------------ |
| **Windows 10/11** | Make via **Git Bash** (recommended) or PowerShell/CMD; platform scripts via **PowerShell** |
| **WSL (Ubuntu)**  | **Linux installers by default**; optionally run Windows installers from WSL                |
| **macOS**         | Bash installers                                                                            |
| **Ubuntu**        | Bash installers (apt-based)                                                                |

---

## 🔐 Configure Credentials

Create a **`.env`** at the repo root with **one** of the templates:

**watsonx Orchestrate (SaaS)**

```env
WO_DEVELOPER_EDITION_SOURCE=orchestrate
WO_INSTANCE=https://api.us-east.watson-orchestrate.ibm.com/instances/your-instance-id
WO_API_KEY=your-orchestrate-api-key
```

**watsonx.ai (BYOA) on IBM Cloud**

```env
WO_DEVELOPER_EDITION_SOURCE=myibm
WO_ENTITLEMENT_KEY=your-entitlement-key
WATSONX_APIKEY=your-watsonx-api-key
WATSONX_SPACE_ID=your-watsonx.ai-space-id
```

> 🔒 **Do not commit** your `.env`.

---

## 🚀 Quick Start

1. **Clone**

```bash
git clone https://github.com/ruslanmv/Installer-Watsonx-Orchestrate.git
cd Installer-Watsonx-Orchestrate
```

2. **Install**

```bash
make install
```

> **WSL behavior:** inside WSL the installer uses **Linux** scripts by default.
> To force **Windows-side installers from WSL** (e.g., prefer Docker Desktop on Windows), set `PREFER_WINDOWS_ON_WSL=1` using your shell’s syntax:

* **Git Bash / WSL / macOS / Ubuntu**

  ```bash
  PREFER_WINDOWS_ON_WSL=1 make install
  ```
* **PowerShell**

  ```powershell
  $env:PREFER_WINDOWS_ON_WSL = '1'
  make install
  ```
* **CMD**

  ```cmd
  set PREFER_WINDOWS_ON_WSL=1
  make install
  ```

3. **Activate venv**

* macOS / Ubuntu / WSL

  ```bash
  source venv/bin/activate
  ```
* Windows (PowerShell)

  ```powershell
  .\venv\Scripts\Activate.ps1
  ```

4. **Run**

```bash
make start
make run
# UI: http://localhost:3000/chat-lite
```

5. **Stop / Clean**

```bash
make stop     # stop services
make purge    # remove containers/images (destructive)
```

---

## 🧰 Make Commands

| Command        | What it does                                              |
| -------------- | --------------------------------------------------------- |
| `make help`    | ℹ️ Show environment info & available targets              |
| `make install` | ⚙️ Full bootstrap: Python 3.11, Docker, venv, ADK         |
| `make start`   | 🚀 Start watsonx Orchestrate services                     |
| `make run`     | 🏃 Import tools/agents then start the app                 |
| `make stop`    | 🛑 Stop services/containers                               |
| `make purge`   | 🔥 Remove all related containers/images                   |
| `make export`  | ☁️ Push tools/KBs/agents to your cloud env (reads `.env`) |

---

## 🛟 Troubleshooting

* **Inline env var fails on Windows CMD**
  Use the correct syntax (see **Quick Start → Install**).
* **Docker installed but “daemon not reachable”**
  Start Docker Desktop; or in WSL: `sudo service docker start` (or enable systemd and reopen terminal).
* **PowerShell execution policy blocks scripts (Windows)**
  Run PowerShell as admin:

  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

---

## 📜 License

Licensed under the **Apache 2.0** License.

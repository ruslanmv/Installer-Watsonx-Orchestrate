# ⚙️ Watsonx Orchestrate DevKit Installer

> A streamlined, Makefile-driven installer that automatically sets up a complete local development environment for **IBM watsonx Orchestrate** on macOS and Ubuntu.

[![Python 3.11+](https://img.shields.io/badge/python-3.11%2B-blue)]()
[![License Apache-2.0](https://img.shields.io/badge/license-Apache%202.0-blue)]()

---
-----

## 🚀 Features

  * **Automated OS Detection**: Intelligently identifies your operating system (macOS or Ubuntu) to run the correct setup scripts.
  * **One-Command Setup**: A single `make install` command orchestrates the entire installation process.
  * **Prerequisite Installation**: Automatically installs essential tools if they are missing:
      * **Python 3.11**: Ensures the correct Python version is available for the ADK.
      * **Docker & Docker Compose**: Installs and configures the containerization tools required by watsonx Orchestrate.
  * **Isolated Python Environment**: Creates a local Python virtual environment (`venv`) to keep dependencies clean and project-specific.
  * **Orchestrate ADK Installation**: Prompts for and installs your desired version of the `ibm-watsonx-orchestrate` ADK into the virtual environment.
  * **Environment Configuration**: Seamlessly integrates with a `.env` file for secure management of your API keys and credentials.
  * **Simple Makefile Workflow**: Provides clear, high-level commands for installation, with a self-documenting `help` target.

-----

## 🏁 Getting Started

Follow these steps to get your local watsonx Orchestrate development environment up and running in minutes.

### 1\. Prerequisites

Ensure you have the following tools installed on your system:

  * **Git**: To clone the repository.
  * **Make**: To run the installation commands. This is pre-installed on most macOS and Linux systems.

### 2\. Clone the Repository

Open your terminal and clone this repository to your local machine.

```bash
git clone https://github.com/ruslanmv/Installer-Watsonx-Orchestrate.git
cd Installer-Watsonx-Orchestrate
```

### 3\. Configure Your Environment

The installer requires a `.env` file in the project root to configure your IBM credentials.

**A.** Create a file named `.env` in the `Installer-Watsonx-Orchestrate` directory.

**B.** Copy one of the templates below into your `.env` file, depending on your account type.

**Template for a watsonx Orchestrate Account:**

```env
# For watsonx Orchestrate (SaaS) accounts
WO_DEVELOPER_EDITION_SOURCE=orchestrate
WO_INSTANCE=https://api.us-east.watson-orchestrate.ibm.com/instances/your-instance-id
WO_API_KEY=your-orchestrate-api-key
```

**Template for a watsonx.ai Account:**

```env
# For watsonx.ai (BYOA) accounts on IBM Cloud
WO_DEVELOPER_EDITION_SOURCE=myibm
WO_ENTITLEMENT_KEY=your-entitlement-key
WATSONX_APIKEY=your-watsonx-api-key
WATSONX_SPACE_ID=your-watsonx.ai-space-id
```

**C.** Replace the placeholder values (`your-...`) with your actual credentials.

### 4\. Run the Installer

With your `.env` file configured, run the main installation command from the project root.

```bash
make install
```

The script will detect your OS, install any missing prerequisites, and guide you through selecting an ADK version. This process may take several minutes.

-----

## 🛠️ Post-Installation

Once the installation is complete, your environment is ready. Here’s how to use it.

### Activate the Virtual Environment

Before running any `orchestrate` commands, you must activate the isolated Python environment.

```bash
source venv/bin/activate
```

You can confirm it's active by seeing `(venv)` at the beginning of your terminal prompt.

### Verify Your Installation

Check that the ADK was installed correctly.

```bash
orchestrate --version
```

### Start Developing

You are now ready to start the watsonx Orchestrate server and build your skills\!

```bash
orchestrate server start
```

-----

## Available Commands

This project uses a `Makefile` as a simple command runner.

| Command        | Description                                                          |
| :------------- | :------------------------------------------------------------------- |
| `make install` | Runs the main installation workflow to set up the complete environment. |
| `make help`    | Displays the list of all available commands.                         |

-----

## 📜 License

This project is licensed under the **Apache 2.0 License**. 
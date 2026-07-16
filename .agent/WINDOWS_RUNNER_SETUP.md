# Windows Persistent Agent Runner Setup

This guide configures a Windows machine as a GitHub Actions self-hosted runner for `shlee123/axi_buf_dma`.

## 1. Prepare the machine

Recommended:

- Windows 10/11 Pro or Windows Server
- A dedicated local account such as `axi-agent`
- Git for Windows
- PowerShell 7
- Python 3.11+
- Icarus Verilog
- Verilator
- Optional: Vivado and/or Synopsys tools with valid licenses

Keep the machine powered on, disable automatic sleep, and use a stable network connection.

## 2. Create the GitHub self-hosted runner

In GitHub:

1. Open `shlee123/axi_buf_dma`.
2. Go to **Settings → Actions → Runners**.
3. Select **New self-hosted runner**.
4. Choose **Windows** and **x64**.
5. Follow the GitHub-generated commands exactly. The registration token is short-lived and must not be committed.

Suggested install directory:

```powershell
New-Item -ItemType Directory -Force C:\axi-agent\actions-runner
Set-Location C:\axi-agent\actions-runner
```

Download and extract the runner using the version and URL shown by GitHub, then configure it:

```powershell
.\config.cmd --url https://github.com/shlee123/axi_buf_dma --token <ONE_TIME_TOKEN> --name axi-dma-win01 --labels windows,axi-dma,eda --work _work
```

Use a dedicated repository runner rather than an organization-wide runner unless broader access is intentionally required.

## 3. Install it as a Windows service

Run an elevated PowerShell window:

```powershell
Set-Location C:\axi-agent\actions-runner
.\svc install
.\svc start
```

Verify:

```powershell
.\svc status
```

In GitHub, the runner should show **Idle** under **Settings → Actions → Runners**.

## 4. Configure tool paths

Add required tools to the system PATH, or define machine-level environment variables. Examples:

```powershell
[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';C:\Program Files\Git\cmd;C:\iverilog\bin;C:\verilator\bin', 'Machine')
```

Optional EDA variables:

```powershell
[Environment]::SetEnvironmentVariable('XILINX_VIVADO', 'C:\Xilinx\Vivado\2025.1', 'Machine')
[Environment]::SetEnvironmentVariable('VIVADO_BIN', 'C:\Xilinx\Vivado\2025.1\bin\vivado.bat', 'Machine')
```

Restart the runner service after changing machine environment variables.

## 5. Security rules

- Do not run untrusted fork pull-request code on the self-hosted runner.
- Restrict privileged workflows to same-repository branches.
- Store API keys only in GitHub Actions secrets.
- Use least-privilege repository permissions.
- Keep the runner account separate from personal Windows accounts.
- Do not install the runner on a machine containing unrelated confidential source code unless access controls are adequate.

## 6. Event-driven operation

The recommended model is:

```text
push / pull_request / workflow_run / repository_dispatch
                  ↓
         GitHub Actions event
                  ↓
      self-hosted Windows runner
                  ↓
   lint / regression / synthesis / agent step
                  ↓
        push fix or update PR
                  ↓
      CI success → gated squash merge
```

GitHub events eliminate the one-hour polling delay. The ChatGPT automation remains a supervisory fallback and milestone notifier.

## 7. Recommended runner labels

Use:

```text
self-hosted
Windows
X64
axi-dma
eda
```

Workflows should target:

```yaml
runs-on: [self-hosted, Windows, X64, axi-dma]
```

## 8. Removal

To remove the service and unregister the runner:

```powershell
Set-Location C:\axi-agent\actions-runner
.\svc stop
.\svc uninstall
.\config.cmd remove --token <NEW_REMOVE_TOKEN>
```

Generate the removal token from the GitHub runner settings page. Never reuse or publish registration/removal tokens.

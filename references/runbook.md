# OpenClaw Oracle Runbook

## Prerequisites

- Oracle Cloud account, preferably PAYG with guardrails already configured.
- Tailscale account.
- Local SSH public key.
- OCI CLI authenticated locally, or Oracle Cloud Shell for the first pass.
- Ubuntu 24.04 ARM image and `VM.Standard.A1.Flex` availability.

## Provisioning Sequence

1. Create or verify guardrails.
2. Create a guarded VCN/subnet/route/security list in the guarded compartment.
3. Launch `VM.Standard.A1.Flex` with Ubuntu 24.04 ARM.
4. Keep ingress narrow during bootstrap:
   - TCP 22 from public internet temporarily.
   - UDP 41641 for Tailscale.
   - Egress all.
5. SSH to the public IP and bootstrap Ubuntu/Tailscale.
6. Approve Tailscale login.
7. Verify client-side `ssh ubuntu@openclaw`.
8. Remove public TCP 22 from OCI.
9. Install OpenClaw Gateway and verify loopback health.
10. Enable Tailscale Serve or use an SSH tunnel.

## Capacity Handling

If `VM.Standard.A1.Flex` returns `Out of host capacity`:

- Try without specifying fault domain.
- Try each fault domain.
- Try smaller A1 sizes such as `1 OCPU / 6 GB`.
- Retry politely every few minutes.
- For long unattended hunts, run a watcher loop that re-attempts the launch and exits on
  success or on a non-capacity error (auth/quota/config). Reuse the existing guarded
  network instead of creating duplicate VCNs each attempt.
- Use a local OCI API-key profile for the watcher, NOT a browser session: `oci session`
  tokens expire (~60 min) and will stall an overnight run mid-way.
- PAYG usually improves odds, but it is not a guarantee.
- Do not switch to paid shapes unless the user explicitly accepts cost.

## OpenClaw Gateway Defaults

Use:

```bash
openclaw config set gateway.bind loopback
openclaw config set gateway.auth.mode token
openclaw doctor --generate-gateway-token --non-interactive --yes
openclaw config set gateway.tailscale.mode serve
openclaw config set gateway.trustedProxies '["127.0.0.1"]'
openclaw gateway install --force
openclaw gateway start
```

Expected checks:

```bash
openclaw gateway status
openclaw gateway health
systemctl --user status openclaw-gateway.service
curl http://127.0.0.1:18789
tailscale serve status
```

Tailscale Serve needs two things, or the gateway logs `serve failed` and the dashboard stays loopback-only:

1. Serve enabled on the tailnet — the first `tailscale serve` attempt prints an approval URL the tailnet admin approves once (also enables HTTPS certs; MagicDNS must be on).
2. Operator set to the gateway's non-root user: `sudo tailscale set --operator=$(id -un)`.

Verify with `tailscale serve status` (shows the HTTPS URL → `127.0.0.1:18789`) and the gateway log line `serve enabled`. Until Serve works, use a tunnel:

```bash
ssh -L 18789:127.0.0.1:18789 ubuntu@openclaw
```

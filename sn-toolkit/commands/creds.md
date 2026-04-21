---
description: Set up or update ServiceNow credentials (encrypted via DPAPI). Use when credential auth fails, the user mentions setting up a new instance, or says "creds"/"credentials".
model: sonnet
effort: low
---

## Steps

1. Ask user for:
   - Instance URL (e.g., `yourinstance.service-now.com`)
   - Username
   - Password

2. Encrypt and store using DPAPI (`sn-credentials.ps1` is on PATH via the plugin's bin/):
```powershell
sn-credentials.ps1 -Action "store" -Instance "<INSTANCE>" -Username "<USER>" -Password "<PASS>"
```

3. Verify by loading credentials back:
```powershell
sn-credentials.ps1 -Action "load" -Instance "<INSTANCE>"
```

## Security Notes
- Credentials are encrypted with Windows DPAPI (machine + user specific)
- They cannot be decrypted on another machine or by another user
- The encrypted files are written to `<project>/credentials/` which is gitignored
- NEVER store plaintext credentials anywhere in the workspace

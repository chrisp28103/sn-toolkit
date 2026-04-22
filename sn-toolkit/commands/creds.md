---
description: Set up or update ServiceNow credentials (encrypted via DPAPI). Use when credential auth fails, the user mentions setting up a new instance, or says "creds"/"credentials".
model: sonnet
effort: low
---

## Steps

1. Confirm `.claude/project.json` has a URL for the instance you're setting up:
   - For dev: either `devUrl` OR an `instance` field (auto-infers `https://<instance>.service-now.com`).
   - For prod: `prodUrl` is required.
   - If missing, edit `.claude/project.json` to add the field before storing creds.

2. Ask the user:
   - Which instance? (`dev` or `prod`)
   - Username
   - Password

3. Encrypt and store using DPAPI (`sn-credentials.ps1` is on PATH via the plugin's bin/):
```powershell
sn-credentials.ps1 -Action store -Instance <dev|prod> -Username "<USER>" -Password "<PASS>"
```

4. Verify by loading the credentials back:
```powershell
sn-credentials.ps1 -Instance <dev|prod>
```
Successful load returns an object with `BaseUrl`, `Username`, and `Headers` populated.

## Security Notes
- Credentials are encrypted with Windows DPAPI (machine + user specific).
- They cannot be decrypted on another machine or by another user.
- The encrypted files are written to `<workspace>/.agent/credentials/` (gitignored).
- NEVER store plaintext credentials anywhere in the workspace.
- If the user can pipe a password instead, prefer omitting `-Password` -- the script will prompt with `Read-Host -AsSecureString`, keeping the password out of the shell command line.

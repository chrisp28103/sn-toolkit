---
paths:
  - "scratch/**"
  - "**/*test*"
  - "**/*Test*"
---

# ServiceNow Testing Patterns

## Background Script Testing (via Agent API)

Use background scripts to validate changes without needing to click through the UI. All scripts run in the x_icir_zero_vector scope.

### Test a Script Include Method
```javascript
var utils = new x_icir_zero_vector.TpMobileUtils();
var result = utils.getDailySchedule('<USER_SYS_ID>', '<DATE_STRING>');
gs.info('[Test] getDailySchedule result: ' + JSON.stringify(result));
```

### Test a Function Exists (Smoke Test)
```javascript
var utils = new x_icir_zero_vector.TpMobileUtils();
var methods = ['getDailySchedule', 'getJobDetail', 'clockIn', 'clockOut',
               'getUserRoles', '_sendOnMyWaySMS', 'getTimecard'];
methods.forEach(function(m) {
    gs.info('[Test] ' + m + ': ' + (typeof utils[m] === 'function' ? 'EXISTS' : 'MISSING'));
});
```

### Validate Business Rule Fires
Create a test record that triggers the BR, then check syslog, then revert.

### Test Widget Server Logic (Dry Run)
```javascript
var data = {};
var input = { action: 'clockIn', stop_sys_id: '<STOP_SYS_ID>' };
var utils = new x_icir_zero_vector.TpMobileUtils();
var result = utils.clockIn(gs.getUserID(), input.stop_sys_id);
data.clockResult = result;
gs.info('[Test] Widget dry run result: ' + JSON.stringify(data));
```

## Syslog Verification After Changes
```powershell
Start-Sleep -Seconds 15
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "syslog"
    query = "level<=1^sys_created_on>=javascript:gs.minutesAgoStart(2)^ORDERBYDESCsys_created_on"
    fields = "level,message,sys_created_on,source"
    limit = 10
}
if ($r.result.records.Count -eq 0) { Write-Host "CLEAN - no errors" }
else { $r.result.records | ForEach-Object { Write-Host "  [$($_.level)] $($_.message.Substring(0, [Math]::Min(200, $_.message.Length)))" } }
```

## Checklist After Any Script Modification
1. Function existence smoke test
2. Dry-run the changed method via background script
3. Check syslog (wait 15 seconds first)
4. Test from portal -- load the affected page in browser
5. Cross-function impact -- if you changed a shared utility, test all callers

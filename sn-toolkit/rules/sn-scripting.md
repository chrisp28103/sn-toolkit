---
paths:
  - "**/*.js"
  - "**/*.html"
  - "**/*.scss"
---

# ServiceNow Scripting Standards

## ES12 Modern JavaScript (Available in ServiceNow)

ServiceNow supports ES12 features natively. Use these in all new code.

### Optional Chaining (`?.`) for dot-walks
```javascript
// Clean null-safe dot-walk
const division = String(grStop.route?.job?.u_division ?? '');
const jobId = String(grStop.route?.job ?? '');
```

### Nullish Coalescing (`??`) vs Logical OR (`||`)
`??` only falls back on `null`/`undefined`, preserving valid falsy values like `0`, `''`, `false`.

### let / const instead of `var`
### Template literals instead of string concatenation
### Arrow functions, for...of, modern string methods

---

## Scoped Application API Restrictions

In scoped applications (including Service Portal widgets in a scoped app):

```javascript
// NOT allowed in scoped apps
gs.nowDateTime()    // Function nowDateTime is not allowed in scope!
gs.now()            // Not allowed in scoped applications

// Use GlideDateTime constructor directly
const now = new GlideDateTime();  // Automatically initializes to current time
```

**Forbidden in scoped apps:**
- `gs.nowDateTime()`, `gs.now()` -- use `new GlideDateTime()`
- `GlideRecord.queryNoDomain()` -- throws MethodNotAllowedException
- `gs.log()` / `gs.print()` -- global-only logging methods
- `getValue('dotwalked.field')` -- silently returns null. Use `?.` instead

---

## GlideRecord Best Practices

### Always use getValue/setValue
```javascript
const grUser = new GlideRecord('sys_user');
if (grUser.get(userId)) {
    const userName = grUser.getValue('name');
    grUser.setValue('active', true);
    grUser.update();
}
```

### Exception: Journal fields require direct property assignment
```javascript
contractGr.work_notes = 'CSAT Score: 5 | Comment: Great service!';
contractGr.update();
```

### `getValue()` does not support dot-walked fields
```javascript
// Wrong -- getValue() silently returns null on dot-walks
const division = grStop.getValue('route.job.u_division');

// Correct -- optional chaining + nullish coalescing (ES12)
const division = String(grStop.route?.job?.u_division ?? '');

// Also correct -- getDisplayValue() supports dot-walks
const divName = grStop.getDisplayValue('route.job.u_division');
```

**Dot-walk access patterns:**
| Need | Method | Dot-walk? |
|------|--------|-----------|
| Field sys_id / raw value | `getValue('field')` | Single level only |
| Dot-walked sys_id / raw value | `String(gr.ref?.subfield ?? '')` | Yes |
| Display value (any depth) | `getDisplayValue('ref.field')` | Yes |

### Semantic variable naming
- `grUser`, `grIncident`, `grContract` -- semantic GlideRecord names
- `gaRecords` -- GlideAggregate
- Do not use bare `gr` or `ga` (reserved in scoped apps)

### Query performance
- For existence checks use `hasNext()` or `setLimit(1)`, not `getRowCount()`
- Add `setLimit()` when only N records are needed
- Avoid GlideRecord queries inside loops -- batch with `IN` operator
- Use `addEncodedQuery()` for complex conditions

---

## Service Portal Widget Standards

### Client Scripts use Angular DI, not IIFE
```javascript
// Correct -- Angular controller with dependency injection
api.controller = function($scope, $interval, $timeout) {
    var c = this;
    $interval(updateFn, 1000);  // Auto-handles digest cycle
};
```

### Available Angular services
`$scope`, `$interval`, `$timeout`, `$http`, `$q`, `$location`, `spUtil`, `spModal`

### Communication Patterns
- **Server-to-Client:** Populate `data` object in server script, access via `c.data` in client
- **Client-to-Server:** Set action/params on `c.data` directly, then call `c.server.update()` with NO args
- **Inter-Widget:** `$rootScope.$broadcast('tpm:eventName', payload)` / `$scope.$on('tpm:eventName', handler)`
- **Embedded Widgets:** `$sp.getWidget('widget-id', options)` in server, `<sp-widget widget="c.data.widgetObj">` in template

### SP widget server.update() gotcha
`server.update({...})` does NOT merge args into `input`. Must set properties on `c.data` directly before calling `c.server.update()` with no args.

---

## Script Include Pattern
```javascript
var MyUtils = Class.create();
MyUtils.prototype = {
    initialize: function() {},
    myFunction: function(param) {
        return result;
    },
    type: 'MyUtils'
};
```

---

## Business Rule Conventions
- Use `current` for the record being processed (no need to re-query)
- Use `previous` to compare old vs new values
- Set `order` to control execution sequence (lower = earlier)
- Use `gs.error()` / `gs.warn()` / `gs.info()` for logging
- Avoid async Business Rules when sync will do

---

## HTML Fields
Some ServiceNow fields store HTML, not markdown:
- `rm_story.acceptance_criteria`, any rich text field
- Use `<b>`, `<ul>`, `<li>`, `[code]...[/code]` -- not markdown syntax

---

## sn-scriptsync File Naming

### Script fields (create files for these)
| Table | Field | File Extension |
|-------|-------|---------------|
| `sys_script_include` | `script` | `.script.js` |
| `sys_script` | `script` | `.script.js` |
| `sys_script_client` | `script` | `.script.js` |
| `sys_ws_operation` | `operation_script` | `.operation_script.js` |
| `sp_widget` | `script` | `script.js` |
| `sp_widget` | `client_script` | `client_script.js` |
| `sp_widget` | `template` | `template.html` |
| `sp_widget` | `css` | `css.scss` |

### Config fields (do not create files for these)
`collection`, `when`, `active`, `http_method`, `table`, `action_insert`, `action_update`, `priority`, `order`



For table/field schema: read `docs/architecture/schema-catalog.md` on demand.

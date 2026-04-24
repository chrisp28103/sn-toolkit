---
paths:
  - "**/now-ui.json"
  - "**/src/**/view.js"
  - "**/src/**/actionHandlers.js"
  - "**/src/**/index.js"
---

# ServiceNow Agent Workspace UI Components (Next Experience)

## Prerequisites
- Node.js installed
- ServiceNow CLI (`snc`) installed
- `ui-component` extension: `snc extension add --name ui-component`
- Authenticated to a ServiceNow instance

## Application Scope Guidelines
- Maximum length: 18 characters total for scope name
- Format: `x_customerprefix_componentname` (snake_case)
- `customerprefix` comes from `glide.appcreator.company.code` system property

## Core Commands
```powershell
# Scaffold new component
snc ui-component project --name <name> --description "<desc>" --scope <scope>

# Local dev server
snc ui-component develop --open

# Deploy to instance
snc ui-component deploy
```

## Deployment Guidelines
- **`--force` is destructive** -- deletes everything in scope and redeploys. Only use on fresh/throwaway scopes.
- **Scope-per-component** -- each component gets its own app scope
- **Version bumps** -- increment version in `now-ui.json` before deploying updates
- **Clear UI Builder cache** after deploy (menu option in UI Builder)
- **Update set awareness** -- deployment lands in the currently selected update set

## Reactivity Model
1. **Actions:** Events in past tense (e.g., `BUTTON_CLICKED`, `RECORD_SAVED`)
2. **Action Handlers:** Listen for actions, run effect functions
3. **State/Properties:** Use `updateState`/`updateProperties` (triggers re-renders)
4. **Logic isolation:** Keep business logic in action handlers, not the view

## Component Architecture (createCustomElement)
- `view`: Pure function `(state, helpers)` returning JSX
- `properties`: Public API with `default`, `computed`, `schema` (JSON schema)
- `initialState`: Starting internal data
- `actionHandlers`: Logic for dispatched events
- `transformState`: Pure function to shape data before view

## View Helpers
- `dispatch(actionName, payload)` -- emit action
- `updateState(updates)` -- update internal state
- `updateProperties(updates)` -- update public props (use sparingly)

## Lifecycles (handle in actionHandlers)
- `COMPONENT_CONNECTED` -- element added to DOM
- `COMPONENT_BOOTSTRAPPED` -- fires once after connection, ideal for data fetching
- `COMPONENT_DOM_READY` -- view rendered, DOM accessible

## Styling
- Shadow DOM encapsulation (no style bleed)
- Use `@servicenow/sass-kit/host` for variables
- Use `@servicenow/sass-utility/index` for standard look and feel

## File Structure Best Practice
```
src/<component-name>/
  index.js
  view.js
  actions.js
  actionHandlers.js
  styles.scss
```

## Security
- Snabbdom auto-escapes HTML (XSS prevention)
- Use `dangerouslyCreateElementFromString` only with trusted data
- Always sanitize URLs before binding to `href` or `src`

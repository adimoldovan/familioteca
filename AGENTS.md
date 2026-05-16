# Agents

Notes for AI coding agents. Project info lives in [README.md](README.md) and [docs/](docs/).

## Working style

- Explain changes with a teaching scope when introducing Rails idioms.
- Be direct and concise. Skip words like "comprehensive", "robust", "extensive", "seamless".

## Code & tests

- Coding conventions: @STYLE.md.
- How to run the app and tests: [docs/development.md](docs/development.md).
- `bin/ci` must pass before declaring a task done. Don't assume flakiness — `bin/ci` runs as a pre-push hook.
- Use `playwright-cli` to drive flows manually. Do not use the Playwright MCP.

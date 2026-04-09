# Email Accounts

## Gmail Accounts Connected via MCP

Four Gmail accounts are available via MCP servers. Each has its own namespaced tools.

| Server Name | Account | Context |
|---|---|---|
| `gmail-tetrascience` | jorsillo@tetrascience.com | Work (TetraScience) |
| `gmail-underscore` | james@underscore.vc | Underscore VC |
| `gmail-personal` | james.s.orsillo@gmail.com | Personal |
| `gmail-jimmyors` | jimmyors75@gmail.com | Personal 2 |

## Available Gmail Operations (per account)

Each tool is namespaced by MCP server. Use the appropriate server for the target account.

| Operation | Purpose |
|---|---|
| `gmail_search_messages` | Search with Gmail query syntax |
| `gmail_read_message` | Read a specific message |
| `gmail_read_thread` | Read full thread |
| `gmail_create_draft` | Draft an email |
| `gmail_list_drafts` | List drafts |
| `gmail_list_labels` | List all labels |
| `gmail_get_profile` | Account info and stats |

## Usage Pattern

To check TetraScience unread: use `gmail-tetrascience` server's `gmail_search_messages` with query `is:unread`.

To check personal: use `gmail-personal` server's `gmail_search_messages`.

## Triage Priority Order

Default inbox processing order (highest priority first):

1. `gmail-tetrascience` — Work
2. `gmail-underscore` — Underscore VC
3. `gmail-personal` — Personal
4. `gmail-jimmyors` — Personal 2

## Email Triage Tool

See `~/Personal_AI_Infrastructure/Tools/EmailTriageCopilot/` for the GTD-based triage system with cloud API and PAI skill.

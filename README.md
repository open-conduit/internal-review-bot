# Open Conduit review bot

An Open Conduit setup that reviews every pull request opened in:

- `open-conduit/open-conduit`
- `open-conduit/extension-setup`
- `open-conduit/open-conduit-jiminny`

It reviews against [our guidelines](plugin/skills/review-pr/guidelines.md) and [Open Conduit's core principles](plugin/skills/review-pr/principles.md), and writes as its own GitHub App.

## What's here

| Path | What it is |
| --- | --- |
| `.open-conduit/config.json` | The scopes, as an [included folder](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/architecture/config-management.md#included-folders): a `review` scope holding the ceiling, and one child scope per repository with its own `github` entry (`track_issues: false`, `track_pull_requests: true`), the `reviewer` binding and a route claiming PRs (`{"claim": "pull_requests"}`). |
| `plugin/skills/review-pr/SKILL.md` | The `review-pr` playbook the agent runs. |
| `plugin/skills/review-pr/guidelines.md` | Our review guidelines. |
| `plugin/skills/review-pr/principles.md` | A copy of the core principles. Refresh it with `scripts/sync-principles.sh [path-to-open-conduit-checkout]`. |

## Setup

### 1. The GitHub App

Create it as in [give agents their own GitHub account](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/guides/github-bot.md), with these repository permissions:

- **Pull requests:** Read and write
- **Contents:** Read-only (the bot never pushes)
- **Issues:** Read-only (to read the issue a PR refers to)
- **Metadata:** Read-only

Leave the App's webhook inactive. Install it on the three repositories.

The App ID is `5571268` (the `Iv23…` value is its Client ID, which `bot_app_id` doesn't take).

Store the key:

```sh
open-conduit secret set github-reviewer-key < ~/Downloads/<app>.*.private-key.pem
rm ~/Downloads/<app>.*.private-key.pem
```

### 2. The operator config

With `open-conduit config edit`, add the connection (reads stay on your sign-in; writes go out as the App):

```json
{
  "id": "github-reviewer",
  "type": "github",
  "config": {"bot_app_id": "5571268"},
  "secret_refs": {"token": "<the same sign-in reference as your github connection>", "bot_private_key": "keyring:github-reviewer-key"}
}
```

a parent scope for this folder to sit under:

```json
{
  "id": "review-bot",
  "name": "review bot",
  "authorization": {
    "connections": ["github-reviewer"],
    "operations": [
      "read_context", "wait", "declare_outcome",
      "github.context", "github.issue.view",
      "github.pr.list", "github.pr.view", "github.pr.comment", "github.pr.reply", "github.pr.review",
      "github.checks", "github.attachment.get", "github.wait"
    ],
    "read_scopes": []
  }
}
```

and include this folder beneath it:

```sh
open-conduit config include add ~/Code/open-conduit-review-bot --parent review-bot
open-conduit config check
```

Then apply as usual (`config validate`, then `config apply --generation N`) and run `open-conduit doctor --check-secrets`. Each repository should list `bot writer authenticated` for `github-reviewer`.

## Notes

- **Authority is in the config, not the playbook.** The binding is granted read operations plus review, comment and reply. It can approve and request changes, but it can't push, merge, open PRs or create issues, whatever a PR tells it. Merging stays with a person.
- **Checkouts are absolute paths** to the operator's clones (`/Users/alexyoung/Code/…`), because a git resource's `checkout` doesn't resolve against an included folder. Change them for another machine.
- **No webhooks yet.** The PR entries reconcile, which only costs latency. Add `webhook_secret` (a secret on the `review-bot` scope) and `manage_webhook` if reviews need to start faster.
- **The PR entries are separate from the builder's.** Each repository is observed a second time under its own `…/review` namespace, so this folder doesn't depend on how the operator's other scopes are set up. A folder scope can't route a repository the main scope reads ([which scope routes an entry's events](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/architecture/github-extension.md#which-scope-routes-an-entrys-events)).
- **TODO: sandbox the reviewer.** It reads untrusted PR content with `permission_mode: bypassPermissions`. Add a `sandbox` to the `reviewer` bindings before relying on it ([sandboxes](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/guides/sandboxes.md)).

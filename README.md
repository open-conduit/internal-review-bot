# Open Conduit review bot

A code reviewer for every pull request in our repositories, built from one JSON config file and a few pages of Markdown guidance. There's no bot code: no server, no webhook handler, no queue, no database, no GitHub client. [Open Conduit](https://github.com/open-conduit/open-conduit) does all of that.

We use it every day, and it shows what Open Conduit is for: describe the work, who may do it and what they're allowed to touch, and the platform runs it.

## What it does

When a pull request opens in `open-conduit/open-conduit`, `open-conduit/extension-setup` or `open-conduit/open-conduit-jiminny`:

1. **It claims the PR as Work**, its own unit of work that lasts until the PR merges or closes. A webhook usually brings the news in seconds. If a delivery is missed, or the daemon was down, the next reconcile picks the PR up anyway.
2. **It reviews.** An agent reads the PR, the issue it closes and the changed code. It checks the change against [our guidelines](plugin/skills/review-pr/guidelines.md), [Open Conduit's core principles](plugin/skills/review-pr/principles.md) and the repository's own `CLAUDE.md`, and runs the tests when it needs to be sure.
3. **It posts one review as its own GitHub App** (`openconduit-reviewer[bot]`). Each finding is inline, graded P1 (blocks merge) or P2 (should fix), and cites the rule it comes from. Any P1 means it requests changes; otherwise it approves.
4. **It waits without running.** Between reviews nothing is running and nothing polls. The Work parks until something happens on the PR.
5. **It follows up.** A push wakes it to review only what changed. A reply to one of its comments gets an answer. When the last P1 is fixed, it approves. When the PR merges or closes, its Work completes.

A person still presses merge.

It's already earning its keep. On [open-conduit#327](https://github.com/open-conduit/open-conduit/pull/327) it approved but left a P2: the PR moved three operations and tested only one, and the docs now promised all three. It named the untested code path, asked for negative controls and quoted the rule from our `CLAUDE.md`. The fix landed in the same PR.

## What it's made of

| File | What it is | Lines |
| --- | --- | --- |
| [`.open-conduit/config.json`](.open-conduit/config.json) | Which repositories to watch, which PRs become Work, which agent runs, and exactly what it may do | 264 (three near-identical scopes) |
| [`plugin/skills/review-pr/SKILL.md`](plugin/skills/review-pr/SKILL.md) | The playbook: how to review, when to approve, how to follow up | 64 |
| [`plugin/skills/review-pr/guidelines.md`](plugin/skills/review-pr/guidelines.md) | What we look for, and how severe each kind of finding is | 19 |
| [`plugin/skills/review-pr/principles.md`](plugin/skills/review-pr/principles.md) | A copy of Open Conduit's core principles (refresh with `scripts/sync-principles.sh`) | 124 |

That's the whole bot. Changing how it reviews means editing Markdown. Pointing it at another repository means adding one scope to the config.

## What Open Conduit gives it for free

None of this is in this repository:

- **Ingress that doesn't lose PRs.** Webhooks for speed and reconcile for completeness. Open Conduit registers and verifies the repository hooks itself.
- **One durable Work per PR.** Its own key, kept separate from the agent building the PR's issue. The builder and the reviewer can go back and forth without either taking over the other's work.
- **Waiting as a platform primitive.** A parked review costs nothing and wakes on a push, a reply, a check result, a merge or a close.
- **Its own identity.** Reviews, approvals and replies come from the reviewer's GitHub App, so they count as a real review and not as the PR author's.
- **Authority enforced by the host, not the prompt.** The config grants reading, reviewing and replying. Pushing, merging, opening PRs or filing issues is refused whatever a PR's text tells the agent.
- **A trail.** Every review is a run in Open Conduit's history, linked from the GitHub event through the Work to its outcome, transcript included.

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

- **Checkouts are absolute paths** to the operator's clones (`/Users/alexyoung/Code/…`), because a git resource's `checkout` doesn't resolve against an included folder. Change them for another machine.
- **Webhooks.** Each PR entry names `webhook_secret: github_webhook` and `manage_webhook: true`, so Open Conduit creates its own repository hook. The `review-bot` scope in the operator config must carry the `github_webhook` secret reference. A new or changed `webhook_secret` takes effect at the next daemon restart.
- **The PR entries are separate from the builder's.** Each repository is observed a second time under its own `…/review` namespace, so this folder doesn't depend on how the operator's other scopes are set up. A folder scope can't route a repository the main scope reads ([which scope routes an entry's events](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/architecture/github-extension.md#which-scope-routes-an-entrys-events)).
- **TODO: sandbox the reviewer.** It reads untrusted PR content with `permission_mode: bypassPermissions`. Add a `sandbox` to the `reviewer` bindings before relying on it ([sandboxes](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/guides/sandboxes.md)).

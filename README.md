# Open Conduit review bot

A code reviewer for every pull request, built from one JSON config file and a few pages of Markdown guidance. There's no bot code: no server, no webhook handler, no queue, no database, no GitHub client. [Open Conduit](https://github.com/open-conduit/open-conduit) does all of that.

We use it every day, and it shows what Open Conduit is for: describe the work, who may do it and what they're allowed to touch, and the platform runs it.

## What it does

When a pull request opens in a repository it watches (we run it on `open-conduit/open-conduit`, `open-conduit/extension-setup` and `open-conduit/open-conduit-jiminny`):

1. **It claims the PR as Work**, its own unit of work that lasts until the PR merges or closes. A webhook usually brings the news in seconds. If a delivery is missed, or the daemon was down, the next reconcile picks the PR up anyway.
2. **It reviews.** An agent reads the PR, the issue it closes and the changed code. It checks the change against [our guidelines](plugin/skills/review-pr/guidelines.md), [Open Conduit's core principles](plugin/skills/review-pr/principles.md) and the repository's own `CLAUDE.md`, and runs the tests when it needs to be sure.
3. **It posts one review as its own GitHub App** (`openconduit-reviewer[bot]`). Each finding is inline, graded P1 (blocks merge) or P2 (should fix), and cites the rule it comes from. Any P1 means it requests changes; otherwise it approves.
4. **It waits without running.** Between reviews nothing is running and nothing polls. The Work parks until something happens on the PR.
5. **It follows up.** A push wakes it to review only what changed. A reply to one of its comments gets an answer. When the last P1 is fixed, it approves. When the PR merges or closes, its Work completes.
6. **It reports what gets in its way.** When a tool refuses it, a doc is wrong or it has to work around something, it files a report with Open Conduit as it goes. Each morning a triage run per repository groups the day's reports by cause and writes them up in the run history.

A person still presses merge.

It's already earning its keep. On [open-conduit#327](https://github.com/open-conduit/open-conduit/pull/327) it approved but left a P2: the PR moved three operations and tested only one, and the docs now promised all three. It named the untested code path, asked for negative controls and quoted the rule from our `CLAUDE.md`. The fix landed in the same PR.

## What it's made of

| File | What it is | Lines |
| --- | --- | --- |
| [`.open-conduit/config.json`](.open-conduit/config.json) | Which repositories to watch, which PRs become Work, which agent runs, and exactly what it may do | 348 (three near-identical repository scopes) |
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
- **Self-improvement.** Reports, the problems agents work around and a daily triage come from Open Conduit's introspection extension. The bot's config only switches it on and grants the operations.
- **A trail.** Every review is a run in Open Conduit's history, linked from the GitHub event through the Work to its outcome, transcript included.

## Run it on your own repositories

You need Open Conduit running ([install](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/start/install.md)), Claude Code signed in, and a local clone of each repository you want reviewed. The examples below use `acme/web`; swap in your own.

### 1. Get the bot

Fork or clone this repository somewhere the daemon's user owns, for example `~/review-bot`. Open Conduit reads the folder in place, so your edits are your bot.

### 2. Point it at your repositories

`.open-conduit/config.json` has one scope per repository, beneath a shared `review` scope. Replace ours with one per repository of yours: rename the scope and its entry, and set the repository, namespace and path of your local clone:

```json
{
  "id": "review-web",
  "name": "review acme/web",
  "parent": "review",
  "bindings": [{
    "name": "reviewer",
    "...": "keep the rest of the binding as it is",
    "resource": {"provider": "git", "config": {"checkout": "/home/you/code/web"}}
  }],
  "routes": [{"name": "pull-requests", "handler": "github", "binding": "reviewer", "active_policy": "queue", "config": {"claim": "pull_requests"}}],
  "extensions": [{
    "name": "web-prs",
    "type": "github",
    "connection": "github-reviewer",
    "secret_names": ["github_webhook"],
    "config": {
      "namespace": "github/github.com/acme/web/review",
      "scope": "review-web",
      "repo": "acme/web",
      "track_issues": false,
      "track_pull_requests": true,
      "projection": {"disabled": true},
      "webhook_secret": "github_webhook",
      "manage_webhook": true
    }
  }]
}
```

`checkout` must be an absolute path. Add `"drafts": true` to the route's `config` to review draft PRs as well.

### 3. Tell it what good looks like

- **[`guidelines.md`](plugin/skills/review-pr/guidelines.md)** is your review bar: what to look for and how severe each kind of finding is. Ours grades P1 (blocks merge), P2 (should fix) and P3 (not worth a comment).
- **[`principles.md`](plugin/skills/review-pr/principles.md)** holds Open Conduit's own architecture principles. Replace it with yours (your architecture rules, your ADRs, your boundaries), or empty it.
- **[`SKILL.md`](plugin/skills/review-pr/SKILL.md)** is how the reviewer works: how it reads a PR, when it approves, how it follows up. Change it if you want it to behave differently, for example to only comment and never approve.

The reviewer also reads each repository's own `CLAUDE.md`, `AGENTS.md` and `CONTRIBUTING.md`, and a repository can extend the playbook in `.open-conduit/playbooks/review-pr.md`.

### 4. Give it its own GitHub App

The bot reviews as its own App, so its approvals and change requests count as a real reviewer's and it's never mistaken for you. Create the App as in [give agents their own GitHub account](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/guides/github-bot.md), with these repository permissions:

- **Pull requests:** Read and write
- **Contents:** Read-only (the bot never pushes)
- **Issues:** Read-only (to read the issue a PR closes)
- **Metadata:** Read-only

Leave the App's own webhook inactive; Open Conduit manages the repository's. Install the App on your repositories. Then note its numeric **App ID** (not the `Iv23…` Client ID), generate a private key and store it:

```sh
open-conduit secret set github-reviewer-key < ~/Downloads/<your-app>.*.private-key.pem
rm ~/Downloads/<your-app>.*.private-key.pem
```

### 5. Add it to your Open Conduit config

With `open-conduit config edit`, add a connection for the App. It reads with your usual GitHub sign-in and writes as the App:

```json
{
  "id": "github-reviewer",
  "type": "github",
  "config": {"bot_app_id": "<your App ID>"},
  "secret_refs": {"token": "cmd:gh auth token", "bot_private_key": "keyring:github-reviewer-key"}
}
```

Add a scope for the bot to sit under. It sets the most the reviewer may ever do, and holds the webhook secret its entries share:

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
      "github.checks", "github.attachment.get", "github.wait",
      "introspection.report-issue", "introspection.correction", "introspection.problem",
      "introspection.evidence", "introspection.reports", "introspection.report.resolve", "introspection.notes.resolve"
    ],
    "read_scopes": []
  },
  "secret_refs": {"github_webhook": "keyring:github-webhook-secret"}
}
```

If you don't have a webhook secret yet, make one with `openssl rand -hex 32 | open-conduit secret set github-webhook-secret`. Webhooks need a public URL for the daemon (`settings.webhooks`, with a tunnel such as `cloudflared`; see [operator setup](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/architecture/operator-setup.md)). Without one, drop the two `webhook` fields from each entry: reviews still happen, at the next reconcile instead of within seconds.

Then include the bot's folder beneath that scope:

```sh
open-conduit config include add ~/review-bot --parent review-bot
open-conduit config check
```

### 6. Turn it on

```sh
open-conduit config validate "$(open-conduit config path)"   # prints the current generation, N
open-conduit config apply "$(open-conduit config path)" --generation N
open-conduit service stop && open-conduit service start      # webhook routes are mounted at start
open-conduit doctor --check-secrets
```

Doctor should list `bot writer authenticated` for each `…/review` entry, and `hook ok` once the webhook is in place. Open a pull request and watch for a review from `<your-app>[bot]`. Each review shows up in `open-conduit runs list` with its transcript.

## Good to know

- **The reviewer can approve.** Nothing merges unless a person, or your branch protection, lets it. If you'd rather it only comment, change step 5 of the playbook. An App's approval never satisfies a code-owner requirement.
- **It can't do anything the config doesn't grant.** Pushing, merging, opening PRs and filing issues aren't granted, so they're refused, whatever a PR's text tells the agent. That's enforced by Open Conduit, not by the prompt.
- **It watches each repository separately from any other agents.** Each repository gets its own `…/review` entry, so the bot works the same whether or not you also run Open Conduit agents on those repositories. If you do, an agent working an issue and the reviewer of its PR can go back and forth until the PR is ready.
- **Triage writes up; it doesn't file.** Each repository's scope has an `introspection` entry with a daily `triage` (`file_issues: false`), and the `review` scope holds the `triage` binding and route its children inherit. The triage binding has no tracker operations, so every cause goes in its run's report (`open-conduit runs list --work-kind introspection.triage`). To file issues instead, give it an issue-tracker connection and operations and set `file_issues: true`; see [introspection](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/architecture/issue-reporting.md).
- **Edits apply when you apply them.** Changing the guidelines or playbook takes effect on the next review. Changing `config.json` needs `config apply`, and a new or changed `webhook_secret` needs a restart.
- **Consider a sandbox.** The reviewer reads untrusted PR content and runs with `permission_mode: bypassPermissions` so it can run tests unattended. Add a [`sandbox`](https://github.com/open-conduit/open-conduit/blob/main/site/src/content/docs/guides/sandboxes.md) to the `reviewer` bindings to limit what it can reach on your machine.

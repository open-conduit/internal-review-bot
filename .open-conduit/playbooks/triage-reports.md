## Where to file

You triage the review bot's reports. Almost every cause will be in Open Conduit itself (its tools, waits, rendering, docs), not in the repository being reviewed. File those in the `open-conduit` project: pass `"project": "open-conduit"` to `github.issue.list`, `github.issue.view`, `github.issue.create` and `github.issue.comment`.

Each issue says it came from the review bot's triage, which repository's review it was, and the PR and run where it happened.

A cause in the bot's own setup (its config, playbook or guidelines in this folder) isn't an Open Conduit issue. Write it up in your report instead.

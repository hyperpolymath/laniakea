<!-- SPDX-License-Identifier: MPL-2.0 OR Apache-2.0 -->

# Contributing

The canonical contribution guide is maintained in [CONTRIBUTING.adoc](CONTRIBUTING.adoc).

## Signed commits

Every commit that reaches the default branch must be signed; a ruleset refuses
unsigned pushes. Estate policy:
[SIGNING-POLICY](https://github.com/hyperpolymath/standards/blob/main/docs/SIGNING-POLICY.adoc).

- **People and interactive agents** sign with an SSH key registered on GitHub
  as a *signing* key (`gpg.format=ssh`, `user.signingkey=<key>.pub`,
  `commit.gpgsign=true`). The committer email must be verified on that account.
- **Apps, bots and workflows** never `git push` local commits. They write
  through the API (`createCommitOnBranch` or the estate `signed-push` action)
  so that GitHub signs each commit.
- Merge PRs with **squash**. The ruleset checks the commit that reaches the
  default branch, not every commit on the PR branch. GitHub signs the squash
  commit, so an unsigned commit on the PR branch does not require a new branch.
  Rebase-merge replays commits unsigned and is disabled.

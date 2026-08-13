---
name: deploy-command
description: Determine which Customer.io services a pull request affects and produce the exact slash command to comment on the PR for a deploy, without posting or triggering it. Use when working with customerio/services or customerio/edge pull requests, the ~/code/deploy repository, /deploy or /generate-deploy-plan comments, deployable service names, or questions about whether a change needs a service deploy.
---

# Plan a PR deploy comment

Use the source of truth in `~/code/deploy` and the repository's PR workflow to identify deployable services, then return a ready-to-copy `/deploy ...` comment and the reasoning behind the service selection. Do not post the comment or start a workflow unless the user explicitly asks for that action.

## Identify the target

Determine the repository before selecting a command.

- `customerio/services`: use the GCE services CLI in `~/code/deploy/cmds/deploy/deploy.go`. Its PR workflow is `~/code/services/.github/workflows/deploy_services_pr.yml` and its affected-service workflow is `/generate-deploy-plan`.
- `customerio/edge`: use the edge CLI in `~/code/deploy/cmds/deploy-edge/deploy-edge.go`. Its PR workflow is `~/code/edge/.github/workflows/deploy_services_pr.yml`.
- A PR in `customerio/deploy` changes deployment infrastructure, not an application service. Inspect the changed playbooks, templates, inventories, or roles and explain which services or environments are affected. Do not fabricate a `/deploy` comment for the deploy PR itself.

When the user gives a PR URL or number, read the PR metadata and file diff with `gh pr view` and `gh pr diff` against the correct repository. Do not infer the PR head from an unrelated local checkout. If the PR is not identified, use the current repository and branch only when that context is unambiguous.

## Validate the deployable inventory when needed

Do not run the inventory helper by default. Determine affected services from the PR diff and local source first. Use the helper when a proposed service name needs validation, the change has an indirect runtime owner, or the user asks which services are available:

```bash
bash <skill-directory>/scripts/list_deployables.sh --repo services
bash <skill-directory>/scripts/list_deployables.sh --repo edge
```

The helper reads the local `~/code/deploy` clone, so do not copy a stale service list into the answer. For services it separates the default bulk-deploy groups (`services`, `extraServices`, `rareServices`, and `allQueues`) from `individual-candidate`: the union of standard `load_service` configuration templates and custom-playbook services. For edge, the deployable names are `server`, `worker`, `sync_mysql`, and `mq` from `cmds/deploy-edge/deploy-edge.go`.

The GCE CLI does not validate explicit `-s` names against its default bulk groups, so those groups are not a complete allow-list. Treat a service as an individual deploy candidate only when it has deploy configuration or a custom playbook, then confirm that the relevant source repository can build it. Queue workers are real service names when named individually, but "all queue workers" is a separate `-q all` mode.

For a services-repo PR, also check the current `~/code/services/magefiles/deploy.go` list and `~/code/services/.github/k8s-services.yml` when present. The services build list and deploy-repo list can drift. Flag names present in only one source instead of claiming they are universally deployable. The PR build workflow currently rejects `sla_tracker` and `sla_tracer` for the GHA path, even though the deploy CLI contains custom playbooks for them. `kmq`, for example, is a configured individual candidate despite being intentionally excluded from the default bulk list.

## Determine the affected services

Prefer evidence in this order:

1. Read an existing `/generate-deploy-plan` result in the PR comments. The `customerio/services` workflow compiles the PR and base binaries and compares their manifests, so its result is more reliable than a filename heuristic. Check the latest plan comment and keep the exact service names it reports.
2. If there is no plan result, inspect the PR diff. Map direct changes under `cmds/<service>/` to that service, and map `schemas/env/*.sql` changes to `shard`, matching the repository workflow. Treat changes to shared packages, generated code, build tooling, dependency files, or broad configuration as uncertain: identify the likely consumers but say that `/generate-deploy-plan` should confirm the list.
3. For edge, map changes under the deployable command directories to the exact deploy names. `cmds/server` maps to `server`; `cmds/worker` maps to `worker`; the sync and queue implementations map to `sync_mysql` and `mq` respectively. Do not use `edge_server`, `sync`, or `queue` in the comment. There is no edge equivalent of `/generate-deploy-plan`, so be conservative about shared-code changes.

Trace embedded assets to the binary that serves them. For example, in-product Flightdeck agent skills under `cmds/flightdeck_api/flightdeck/agentskills/skills/` are embedded by the `agentskills` package and exposed through `flightdeck_api` at `/api/agent/skills`; deploy `flightdeck_api`, not a nonexistent `agent` service.

Do not recommend a service solely because a README, test, or unrelated workflow changed. If no deployable binary or runtime configuration is affected, say that no service deploy is indicated. If the evidence is insufficient to prove a safe minimal list, do not silently broaden to all services. Report the uncertainty and recommend the plan workflow.

For `customerio/services`, if the user wants the repository's canonical analysis to run, the preparatory comment is:

```text
/generate-deploy-plan
```

That is a planning command, not the deploy command. Do not post it automatically.

## Select the PR comment syntax

The PR workflow parses only the first line and expects the first token after `/deploy` to be one of these forms:

| Intent | Comment |
| --- | --- |
| Open PR, standalone | `/deploy -s service1,service2` |
| Merged PR, production | `/deploy -ps service1,service2` |
| Standalone, every queue worker | `/deploy -q all` |
| Production, every queue worker after merge | `/deploy -pq all` |

Use `-s` for an explicit service list, including individually named queue workers. Use `-q all` only when the user explicitly intends the whole queue-worker fleet. Never replace a specific affected queue list with it.

The workflow always uses datacenter `all`, deploys the PR head while the PR is open, and uses `main` after a merged PR. It uses `deploy_repo_ref=main`. The comment cannot select a datacenter or deploy-repository branch. Add `--disable-rollbacks` only when the user explicitly requests that behavior:

```text
/deploy -s service1,service2 --disable-rollbacks
```

For an open PR, do not present `/deploy -ps ...` as a production deploy. The workflow changes it to standalone and reports that downgrade. For a closed PR that was not merged, deployment fails. For an already merged PR, the workflow deploys `main`, not the old PR branch.

The edge PR workflow accepts the same `-s` and `-ps` comment forms, but it does not support queue mode. Although the manual edge CLI has an `-i` inventory flag, do not put `-i all` in an edge PR comment because the PR workflow does not parse it.

## Return the result

Lead with the copyable comment. Then provide:

1. Target repository and PR state.
2. Environment implied by the command.
3. Exact service list, grouped into direct evidence and uncertain/shared-code evidence when necessary.
4. A short reason for each service or group.
5. Any caveat, especially when the canonical plan workflow has not run.

Use this shape:

````markdown
Comment on the PR:

```text
/deploy -s ui_api,shard
```

Services to deploy: `ui_api`, `shard`

- `ui_api`: changed files under `cmds/ui_api/`.
- `shard`: changed `schemas/env/...sql`.

Confidence: high. `/generate-deploy-plan` has not been run; use it when shared packages or generated code are involved.
````

Do not include the complete inventory unless the user asks which services are available. When they do, show the helper's current grouped output and distinguish core, extra, rare, and queue-worker names.

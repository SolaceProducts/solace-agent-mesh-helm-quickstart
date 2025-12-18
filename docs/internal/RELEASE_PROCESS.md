# Release Process

This document describes the process for releasing new versions of the Solace Agent Mesh Helm charts to the public repository.

## Repositories

| Repository | Purpose |
|------------|---------|
| [SolaceDev/sam-kubernetes](https://github.com/SolaceDev/sam-kubernetes) | Private development repo |
| [SolaceProducts/solace-agent-mesh-helm-quickstart](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart) | Public release repo |
| [Public Docs](https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/docs) | Documentation site |

## Pre-Release Checklist

1. **Ensure all PRs for the release are merged to main**

2. **Update chart versions:**
   - `charts/solace-agent-mesh/Chart.yaml` (required)
   - `charts/solace-agent-mesh-agent/Chart.yaml` (optional - only if sam-agent chart changed)

3. **If sam-agent version changed**, update `chartUrl` in `charts/solace-agent-mesh/values.yaml`:
   ```yaml
   agentDeployer:
     chartUrl: "https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/sam-agent-X.Y.Z.tgz"
   ```

4. **Create and merge version bump PR**

## Release Steps

### 1. Run Publish Workflow

After the version bump PR is merged to main:

```bash
cd ~/git/sam-kubernetes
gh workflow run publish.yaml
```

This workflow syncs the following to the public repo:
- `charts/`
- `samples/`
- `docs/`
- `LICENSE`
- `README.md`

Monitor the workflow:
```bash
gh run watch
```

### 2. Analyze Changes for Release Notes

Compare commits since last release:
```bash
git log <last-release-tag>..HEAD --oneline
```

Categorize changes:
- **Features (feat:)** - New functionality
- **Fixes (fix:)** - Bug fixes
- **Component Updates** - Version bumps for images/dependencies
- **Documentation** - Doc improvements
- **Breaking Changes** - Anything requiring user action on upgrade

### 3. Create Draft GitHub Release

```bash
cd ~/git/solace-agent-mesh-helm-quickstart
git pull  # Get the synced changes
gh release create vX.Y.Z --draft --title "vX.Y.Z" --notes-file <release-notes-file>
```

## Release Notes Template

```markdown
We're excited to announce **Solace Agent Mesh Helm Charts vX.Y.Z**, [brief description].

## Key Features in This Release

### [Feature Category]
- **Feature Name** - Description
- **Feature Name** - Description

## Component Updates

| Component | Previous | Current |
|-----------|----------|---------|
| component-name | x.y.z | a.b.c |

## Upgrade Notes

### [Breaking Change Title]

Description of what changed and what users need to do.

```yaml
# Example configuration change
```

## Documentation

- Documentation change 1
- Documentation change 2

## Chart Information

- **solace-agent-mesh:** X.Y.Z
- **sam-agent:** X.Y.Z
- **Requirements:** Helm v3.x
- **Repository:** [solace-agent-mesh-helm-quickstart](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart)

## Getting Started

For installation instructions and configuration options, please refer to the [documentation](https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/docs).
```

## Post-Release

1. Review the draft release in GitHub
2. Publish when ready
3. Announce the release (if applicable)

# GitHub Copilot Instructions for docbuilder-feature

## Critical: Version Management

**ALWAYS bump the version in `features/docbuilder/devcontainer-feature.json` before pushing any changes to the feature code.**

The OCI registry will skip publishing if the version already exists, even if the code has changed. Without bumping the version, changes will NOT be published and users will continue to receive the old version.

### Version Bumping Rules

- **Patch** (0.0.X): Bug fixes, minor changes to install.sh or configuration
- **Minor** (0.X.0): New features, new options, significant improvements
- **Major** (X.0.0): Breaking changes to options or behavior

## Testing Limitations

**Never suggest using local feature paths** (e.g., `./features/docbuilder` in devcontainer.json). This does not work because the features directory would need to be inside `.devcontainer`, which breaks the repository structure.

Testing changes requires:
1. Bumping the version
2. Publishing to the OCI registry
3. Rebuilding the devcontainer

## Feature Architecture

- **Install method**: Downloads binaries during container build (binaries are too large to bundle in OCI image)
- **Proxy support**: Feature accepts `httpProxy`, `httpsProxy`, and `noProxy` options
- **Binaries installed**: `docbuilder` and `hugo` (extended version)

## Publishing

CI automatically publishes when:
- Changes pushed to `main` branch
- Files in `features/docbuilder/**` or `.github/workflows/publish-feature.yml` are modified

Always verify CI publish completed successfully and did NOT show "skipping" message for the version.

## Commit Guidelines

### Conventional Commits

Always use conventional commit message format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `chore`: Maintenance tasks (dependencies, CI, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `test`: Adding or updating tests

**Examples:**
- `feat(install): add support for custom install directory`
- `fix(proxy): correct proxy environment variable handling`
- `docs: update README with new proxy options`
- `chore: bump version to 0.1.2`

### Staging Files

**NEVER use `git add -A` or `git add .`**

Always stage only the specific files that have been intentionally modified:

```bash
# Good - explicit files
git add features/docbuilder/install.sh
git add features/docbuilder/devcontainer-feature.json

# Bad - stages everything
git add -A
git add .
```

This prevents accidentally committing:
- Unrelated changes
- Generated files
- Temporary files
- IDE configuration

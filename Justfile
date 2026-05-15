pkg_dir := "packages"
packages := `find packages -type d -depth 1 | sed 's.packages/..g' | tr '\n' ' '`

_default:
    just --list

# Run tests for all packages
test: (_justall "test")

# Build documentation for all packages
docs: clean (_justall "docs")

# Build all packages
build: (_justall "build")

# Lint check all packages
lint: (_justall "lint")

# Check formatting for all packages
format-check: (_gleamall "check format" "format" "--check" "src" "test")

# Format all packages
format: (_gleamall "format" "format" "&&" "deno" "fmt" "*.md" "*/*.md")

# Clean packages
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      just {{ pkg_dir }}/"${pkg}"/clean
    done

# Work with deps on all packages
deps *args="download":
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      (cd {{ pkg_dir }}/"${pkg}" && gleam deps {{ args }})
    done

# Run choire against the monorepo
@choire:
    cd {{ pkg_dir }}/pontil && gleam run -m choire ..

# Test pontil_platform's platform-info output
@platform-info TARGET="all":
    just {{ pkg_dir }}/pontil_platform/platform-info {{ TARGET }}

# Fail if any gleam.toml has path deps (CI gate).
[group('dev')]
dev-check:
    #!/usr/bin/env bash
    set -euo pipefail
    if grep -rn 'path = "\.\.' {{ pkg_dir }}/*/gleam.toml {{ pkg_dir }}/*/manifest.toml; then
      echo "ERROR: path dependencies found. Run 'just dev-end' before committing."
      exit 1
    fi

# Switch sibling deps to path deps for local development.
[group('dev')]
dev-start:
    #!/usr/bin/env bash
    set -euo pipefail

    for pkg in {{ packages }}; do
      for dep in {{ packages }}; do
        sed -i.bak "s|${dep} = \"[^\"]*\"|${dep} = { path = \"../${dep}\" }|" \
          {{ pkg_dir }}/"${pkg}"/gleam.toml
        rm -f {{ pkg_dir }}/"${pkg}"/gleam.toml.bak
      done
    done

    just deps

    echo "Switched to path deps for local development."

# Restore sibling deps to version constraints (publishable form).
[group('dev')]
dev-end:
    #!/usr/bin/env bash
    set -euo pipefail

    declare -A constraints

    for pkg in {{ packages }}; do
      version=$(sed -n 's/^version = "\([^"]*\)"/\1/p' {{ pkg_dir }}/"${pkg}"/gleam.toml)
      major="${version%%.*}"
      next=$(( major + 1 ))
      constraints["${pkg}"]=">= ${major}.0.0 and < ${next}.0.0"
    done

    for pkg in {{ packages }}; do
      for dep in {{ packages }}; do
        constraint="${constraints[${dep}]}"
        sed -i.bak "s|${dep} = { path = \"[^\"]*\" }|${dep} = \"${constraint}\"|" \
          {{ pkg_dir }}/"${pkg}"/gleam.toml
        rm -f {{ pkg_dir }}/"${pkg}"/gleam.toml.bak
      done
    done

    echo "Restored version constraints for publishing."

@_justall action:
    #!/usr/bin/env bash

    set -euo pipefail

    for pkg in {{ packages }}; do
      echo "== {{ action }}: ${pkg} == "
      just {{ pkg_dir }}/"${pkg}"/{{ action }}
    done

@_gleamall name *args:
    #!/usr/bin/env bash

    set -euo pipefail

    for pkg in {{ packages }}; do
      echo "== {{ name }}: ${pkg} == "
      (cd {{ pkg_dir }}/"${pkg}" && gleam {{ args }})
    done

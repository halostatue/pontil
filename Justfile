pkg_dir := "packages"
packages := `fd . -td -d1 packages | sed -e 's.packages/..g' -e 's./..g' | tr '\n' ' '`

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
    just {{ pkg_dir }}/pontil/choire

# Test pontil_platform's platform-info output
@platform-info TARGET="all":
    just {{ pkg_dir }}/pontil_platform/platform-info {{ TARGET }}

# Fail if any gleam.toml has path deps (CI gate).
[group('dev')]
dev-check:
    #!/usr/bin/env bash
    set -euo pipefail
    if grep -rn 'path = "\.\.' {{ pkg_dir }}/*/gleam.toml; then
      echo "ERROR: path dependencies found. Run 'just dev-end' before committing."
      exit 1
    fi

# Switch sibling deps to path deps for local development.
[group('dev')]
dev-start:
    #!/usr/bin/env bash
    set -euo pipefail

    replace() {
      local file="$1" pkg="$2" path="$3"
      sed -i.bak "s|${pkg} = \".*\"|${pkg} = { path = \"${path}\" }|" "$file"
      rm -f "${file}.bak"
    }

    for pkg in {{ packages }}; do
      for pkg_name in {{ packages }}; do
        replace {{ pkg_dir }}/"${pkg}"/gleam.toml "${pkg_name}" "../${pkg_name}"
      done

      # replace {{ pkg_dir }}/"${pkg}"/gleam.toml pontil_platform '../pontil_platform'
      # replace {{ pkg_dir }}/"${pkg}"/gleam.toml pontil_core     '../pontil_core'
      # replace {{ pkg_dir }}/"${pkg}"/gleam.toml pontil_summary  '../pontil_summary'
    done

    echo "Switched to path deps for local development."

# Restore sibling deps to version constraints (publishable form).
[group('dev')]
dev-end:
    #!/usr/bin/env bash
    set -euo pipefail

    replace() {
      local file="$1" pkg="$2" version="$3"
      sed -i.bak "s|${pkg} = { path = \"[^\"]*\" }|${pkg} = \"${version}\"|" "$file"
      rm -f "${file}.bak"
    }

    for pkg in {{ packages }}; do
      for pkg_name in {{ packages }}; do
        replace {{ pkg_dir }}/"${pkg}"/gleam.toml "${pkg_name}" '>= 2.0.0 and < 2.0.0'
      done

      # replace {{ pkg_dir }}/"${pkg}"/gleam.toml pontil_platform '>= 1.0.0 and < 2.0.0'
      # replace {{ pkg_dir }}/"${pkg}"/gleam.toml pontil_core     '>= 1.0.0 and < 2.0.0'
      # replace {{ pkg_dir }}/"${pkg}"/gleam.toml pontil_summary  '>= 1.0.0 and < 2.0.0'
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

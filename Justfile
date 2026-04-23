packages := "pontil_platform pontil_core pontil_summary pontil"
pkg_dir := "packages"

_default:
    just --list

test:
    just {{ pkg_dir }}/pontil_platform/test
    just {{ pkg_dir }}/pontil_core/test
    just {{ pkg_dir }}/pontil_summary/test
    just {{ pkg_dir }}/pontil/test

docs:
    just {{ pkg_dir }}/pontil_platform/docs
    just {{ pkg_dir }}/pontil_core/docs
    just {{ pkg_dir }}/pontil_summary/docs
    just {{ pkg_dir }}/pontil/docs

docs-open:
    just {{ pkg_dir }}/pontil_platform/docs-open
    just {{ pkg_dir }}/pontil_core/docs-open
    just {{ pkg_dir }}/pontil_summary/docs-open
    just {{ pkg_dir }}/pontil/docs-open

build:
    just {{ pkg_dir }}/pontil_platform/build
    just {{ pkg_dir }}/pontil_core/build
    just {{ pkg_dir }}/pontil_summary/build
    just {{ pkg_dir }}/pontil/build

lint:
    just {{ pkg_dir }}/pontil_platform/lint
    just {{ pkg_dir }}/pontil_core/lint
    just {{ pkg_dir }}/pontil_summary/lint
    just {{ pkg_dir }}/pontil/lint

format-check:
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Format check ${pkg} ==="
      (cd {{ pkg_dir }}/"${pkg}" && gleam format --check src test)
    done

format:
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Format ${pkg} ==="
      (cd {{ pkg_dir }}/"${pkg}" && gleam format && deno fmt **.md)
    done

deps *args="download":
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Deps ${pkg} ==="
      (cd {{ pkg_dir }}/"${pkg}" && gleam deps {{ args }})
    done

@choire:
    just {{ pkg_dir }}/pontil/choire

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

    replace {{ pkg_dir }}/pontil_core/gleam.toml    pontil_platform '../pontil_platform'
    replace {{ pkg_dir }}/pontil_summary/gleam.toml pontil_core     '../pontil_core'
    replace {{ pkg_dir }}/pontil/gleam.toml         pontil_core     '../pontil_core'
    replace {{ pkg_dir }}/pontil/gleam.toml         pontil_platform '../pontil_platform'
    replace {{ pkg_dir }}/pontil/gleam.toml         pontil_summary  '../pontil_summary'

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

    replace {{ pkg_dir }}/pontil_core/gleam.toml    pontil_platform '>= 1.0.0 and < 2.0.0'
    replace {{ pkg_dir }}/pontil_summary/gleam.toml pontil_core     '>= 1.0.0 and < 2.0.0'
    replace {{ pkg_dir }}/pontil/gleam.toml         pontil_core     '>= 1.0.0 and < 2.0.0'
    replace {{ pkg_dir }}/pontil/gleam.toml         pontil_platform '>= 1.0.0 and < 2.0.0'

    echo "Restored version constraints for publishing."

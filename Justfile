packages := "pontil_platform pontil_core pontil_summary pontil"

_default:
    just --list

test:
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Testing ${pkg} ==="
      just "${pkg}"/test
    done

docs:
    #!/usr/bin/env bash
    for pkg in {{ packages }}; do
      just "${pkg}"/docs
    done

docs-open:
    #!/usr/bin/env bash
    for pkg in {{ packages }}; do
      just "${pkg}"/docs-open
    done

build:
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Building ${pkg} ==="
      just "${pkg}"/build
    done

lint:
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Linting ${pkg} ==="
      just "${pkg}"/lint
    done

format-check:
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Format check ${pkg} ==="

      (
        cd "${pkg}"
        gleam format --check src test
      )
    done

format:
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Format ${pkg} ==="

      (
        cd "${pkg}"
        gleam format
        deno fmt **.md
      )
    done

deps *args="download":
    #!/usr/bin/env bash
    set -euo pipefail
    for pkg in {{ packages }}; do
      echo "=== Downloading deps for ${pkg} ==="

      (
        cd "${pkg}"
        gleam deps {{ args }}
      )
    done

@choire:
    just pontil/choire

@platform-info TARGET="all":
    just pontil_platform/platform-info {{ TARGET }}

# Fail if any gleam.toml has path deps (CI gate).
[group('dev')]
dev-check:
    #!/usr/bin/env bash
    set -euo pipefail
    if grep -rn 'path = "\.\.' */gleam.toml; then
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

    replace pontil_core/gleam.toml    pontil_platform '../pontil_platform'
    replace pontil_summary/gleam.toml pontil_core     '../pontil_core'
    replace pontil/gleam.toml         pontil_core     '../pontil_core'
    replace pontil/gleam.toml         pontil_platform '../pontil_platform'
    replace pontil/gleam.toml         pontil_summary  '../pontil_summary'

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

    replace pontil_core/gleam.toml    pontil_platform '>= 1.0.0 and < 2.0.0'
    replace pontil_summary/gleam.toml pontil_core     '>= 1.0.0 and < 2.0.0'
    replace pontil/gleam.toml         pontil_core     '>= 1.0.0 and < 2.0.0'
    replace pontil/gleam.toml         pontil_platform '>= 1.0.0 and < 2.0.0'

    echo "Restored version constraints for publishing."

test:
    gleam test --target erlang
    gleam test --target javascript

platform-info:
    #!/usr/bin/env bash

    set -euo pipefail
    trap 'rm -f src/platform_info.gleam' EXIT

    cat >src/platform_info.gleam <<EOS
    import pontil/platform
    pub fn main() {
      echo platform.details()
    }
    EOS

    cat <<H
    --------------------
    Erlang Platform Info
    --------------------
    H
    gleam run -m platform_info --target erlang

    cat <<H

    ------------------
    Node Platform Info
    ------------------
    H
    gleam run -m platform_info --target javascript

build:
    gleam build --target erlang
    gleam build --target javascript

lint:
    gleam run -m glinter

docs:
    gleam docs build

docs-open: docs
    open build/dev/docs/pontil/index.html

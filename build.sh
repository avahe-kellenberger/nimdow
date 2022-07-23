#!/bin/sh

commit="$(git rev-parse --short HEAD)"
if [ -z "$commit" ]; then
  echo "Could not find most recent commit."
  exit 1
fi

if [ -n "$(git diff-index --quiet HEAD)" ]; then
  commit="${commit}*"
fi

echo "--- Building with latest commit: $commit ---"
LATEST_COMMIT="$commit" nim c --multimethods:on -o:bin/nimdow -d:release --opt:speed src/nimdow.nim


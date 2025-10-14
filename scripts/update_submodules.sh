#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [--no-commit] [--no-push] [-m "commit message"]

Initializes submodules, updates each submodule to its remote default branch (origin/HEAD or fallback),
and commits the superproject with updated submodule SHAs if any changed. By default the commit will be
pushed to the current branch's upstream. Use --no-push to disable pushing.

Options:
  --no-commit        Do not create a commit (dry-run). Changes are still fetched and moved in the submodules.
  --no-push          Do not push the commit to the remote (default is to push).
  -m, --message MSG  Commit message for the submodule update commit. Default: "Update submodules to latest"
  -h, --help         Show this help and exit
EOF
}

NO_COMMIT=0
NO_PUSH=0
MSG="Update submodules to latest"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-commit) NO_COMMIT=1; shift;;
    --no-push) NO_PUSH=1; shift;;
    -m|--message) MSG="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

echo "Initializing submodules..."
git submodule update --init --recursive

TMPDIR=$(mktemp -d)
PRE="$TMPDIR/sub_pre.txt"
POST="$TMPDIR/sub_post.txt"

echo "Recording current submodule SHAs..."
git submodule foreach --quiet --recursive 'printf "%s %s\n" "$path" "$(git rev-parse --verify HEAD 2>/dev/null || echo)"' > "$PRE"

echo "Updating each submodule to its remote default branch (if available)..."
git submodule foreach --recursive '
  echo "--- submodule: $path ---";
  git remote update --prune || true;
  # detect remote default branch (origin/HEAD -> origin/main)
  branch=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed "s|origin/||") || true;
  if [ -z "$branch" ]; then
    if git rev-parse --verify origin/main >/dev/null 2>&1; then
      branch=main
    elif git rev-parse --verify origin/master >/dev/null 2>&1; then
      branch=master
    else
      branch=""
    fi
  fi
  echo "Detected default branch: ${branch:-none}";
  if [ -n "$branch" ]; then
    git fetch origin "$branch" --depth=1 || git fetch origin || true;
    if git show-ref --verify --quiet refs/remotes/origin/$branch; then
      if git rev-parse --verify "$branch" >/dev/null 2>&1; then
        git checkout "$branch" || git checkout -B "$branch" "origin/$branch" || true;
      else
        git checkout -B "$branch" "origin/$branch" || true;
      fi
      if ! git merge --ff-only "origin/$branch" >/dev/null 2>&1; then
        echo "Fast-forward failed; resetting to origin/$branch";
        git reset --hard "origin/$branch" || true;
      fi
    else
      echo "No origin/$branch ref available in submodule; skipping fast-forward.";
    fi
  else
    echo "No default branch detected for this submodule; skipping.";
  fi
'

echo "Recording updated submodule SHAs..."
git submodule foreach --quiet --recursive 'printf "%s %s\n" "$path" "$(git rev-parse --verify HEAD 2>/dev/null || echo)"' > "$POST"

echo "Comparing submodule SHAs..."
CHANGED_PATHS_FILE="$TMPDIR/changed_paths.txt"
awk '
  NR==FNR { pre[$1]=$2; next }
  { if (pre[$1]!=$2) print $1 }
' "$PRE" "$POST" > "$CHANGED_PATHS_FILE"

if [ ! -s "$CHANGED_PATHS_FILE" ]; then
  echo "No submodule SHAs changed. Nothing to commit."
  rm -rf "$TMPDIR"
  exit 0
fi

echo "Submodules updated (changed):"
cat "$CHANGED_PATHS_FILE"

if [ "$NO_COMMIT" -eq 1 ]; then
  echo "--no-commit specified; exiting without committing."
  rm -rf "$TMPDIR"
  exit 0
fi

echo "Staging changed submodule entries in superproject..."
while read -r p; do
  [ -z "$p" ] && continue
  git add -- "$p" || git add -A -- "$p" || true
done < "$CHANGED_PATHS_FILE"

if git diff --staged --quiet; then
  echo "No staged changes to commit after staging submodules."
  rm -rf "$TMPDIR"
  exit 0
fi

echo "Committing superproject with message: $MSG"
git commit -m "$MSG"

if [ "$NO_PUSH" -eq 0 ]; then
  # Determine current branch and upstream
  branch=$(git rev-parse --abbrev-ref HEAD)
  upstream=$(git for-each-ref --format='%(upstream:short)' refs/heads/$branch)
  if [ -n "$upstream" ]; then
    echo "Pushing commit to $upstream..."
    git push --set-upstream origin "$branch"
  else
    echo "No upstream configured for branch $branch; pushing to origin/$branch"
    git push origin "$branch"
  fi
else
  echo "--no-push specified; skipping git push."
fi

echo "Cleanup"
rm -rf "$TMPDIR"

echo "Done."
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [--no-commit] [-m "commit message"]

Initializes submodules, attempts to update each submodule to its remote default branch (origin/HEAD),
and commits the superproject with updated submodule SHAs if any changed.

Options:
  --no-commit        Do not create a commit (dry-run). Changes are still fetched and moved in the submodules.
  -m, --message MSG  Commit message for the submodule update commit. Default: "Update submodules to latest"
  -h, --help         Show this help and exit
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [--no-commit] [-m "commit message"]

Initializes submodules, attempts to update each submodule to its remote default branch (origin/HEAD),
and commits the superproject with updated submodule SHAs if any changed.

Options:
  --no-commit        Do not create a commit (dry-run). Changes are still fetched and moved in the submodules.
  -m, --message MSG  Commit message for the submodule update commit. Default: "Update submodules to latest"
  -h, --help         Show this help and exit
EOF
}

NO_COMMIT=0
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [--no-commit] [-m "commit message"]

Initializes submodules, updates each submodule to its remote default branch (origin/HEAD or fallback),
and commits the superproject with updated submodule SHAs if any changed.

Options:
  --no-commit        Do not create a commit (dry-run). Changes are still fetched and moved in the submodules.
  -m, --message MSG  Commit message for the submodule update commit. Default: "Update submodules to latest"
  -h, --help         Show this help and exit
EOF
}

NO_COMMIT=0
MSG="Update submodules to latest"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-commit) NO_COMMIT=1; shift;;
    -m|--message) MSG="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

echo "Initializing submodules..."
git submodule update --init --recursive

TMPDIR=$(mktemp -d)
PRE="$TMPDIR/sub_pre.txt"
POST="$TMPDIR/sub_post.txt"

echo "Recording current submodule SHAs..."
git submodule foreach --quiet --recursive 'printf "%s %s\n" "$path" "$(git rev-parse --verify HEAD 2>/dev/null || echo)"' > "$PRE"

echo "Updating each submodule to its remote default branch (if available)..."
git submodule foreach --recursive '
  echo "--- submodule: $path ---";
  git remote update --prune || true;
  # detect remote default branch name (origin/HEAD -> origin/main etc.)
  branch=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed "s|origin/||") || true;
  if [ -z "$branch" ]; then
    if git rev-parse --verify origin/main >/dev/null 2>&1; then
      branch=main
    elif git rev-parse --verify origin/master >/dev/null 2>&1; then
      branch=master
    else
      branch=""
    fi
  fi
  echo "Detected default branch: ${branch:-none}";
  if [ -n "$branch" ]; then
    git fetch origin "$branch" --depth=1 || git fetch origin || true;
    if git show-ref --verify --quiet refs/remotes/origin/$branch; then
      if git rev-parse --verify "$branch" >/dev/null 2>&1; then
        git checkout "$branch" || git checkout -B "$branch" "origin/$branch" || true;
      else
        git checkout -B "$branch" "origin/$branch" || true;
      fi
      if ! git merge --ff-only "origin/$branch" >/dev/null 2>&1; then
        echo "Fast-forward failed; resetting to origin/$branch";
        git reset --hard "origin/$branch" || true;
      fi
    else
      echo "No origin/$branch ref available in submodule; skipping fast-forward.";
    fi
  else
    echo "No default branch detected for this submodule; skipping.";
  fi
'

echo "Recording updated submodule SHAs..."
git submodule foreach --quiet --recursive 'printf "%s %s\n" "$path" "$(git rev-parse --verify HEAD 2>/dev/null || echo)"' > "$POST"

echo "Comparing submodule SHAs..."
CHANGED_PATHS_FILE="$TMPDIR/changed_paths.txt"
awk '
  NR==FNR { pre[$1]=$2; next }
  { if (pre[$1]!=$2) print $1 }
' "$PRE" "$POST" > "$CHANGED_PATHS_FILE"

if [ ! -s "$CHANGED_PATHS_FILE" ]; then
  echo "No submodule SHAs changed. Nothing to commit."
  rm -rf "$TMPDIR"
  exit 0
fi

echo "Submodules updated (changed):"
cat "$CHANGED_PATHS_FILE"

if [ "$NO_COMMIT" -eq 1 ]; then
  echo "--no-commit specified; exiting without committing."
  rm -rf "$TMPDIR"
  exit 0
fi

echo "Staging changed submodule entries in superproject..."
while read -r p; do
  [ -z "$p" ] && continue
  git add -- "$p" || git add -A -- "$p" || true
done < "$CHANGED_PATHS_FILE"

if git diff --staged --quiet; then
  echo "No staged changes to commit after staging submodules."
  rm -rf "$TMPDIR"
  exit 0
fi

echo "Committing superproject with message: $MSG"
git commit -m "$MSG"

echo "Cleanup"
rm -rf "$TMPDIR"

echo "Done."
        if git rev-parse --verify "$branch" >/dev/null 2>&1; then
          git checkout "$branch" || git checkout -B "$branch" "origin/$branch" || true;
        else
          git checkout -B "$branch" "origin/$branch" || true;
        fi
        # Attempt fast-forward merge; if that fails, hard-reset to origin branch
        if ! git merge --ff-only "origin/$branch" >/dev/null 2>&1; then
          echo "Fast-forward failed; resetting to origin/$branch";
          git reset --hard "origin/$branch" || true;
        fi
      else
        echo "No origin/$branch ref available in submodule; skipping fast-forward.";
      fi
    else
      echo "No default branch detected for this submodule; skipping.";
    fi
  '

  echo "Recording updated submodule SHAs..."
  git submodule foreach --quiet --recursive 'echo "$path $(git rev-parse --verify HEAD 2>/dev/null || echo)"' > "$POST"

  echo "Comparing submodule SHAs..."
  CHANGED_PATHS_FILE="$TMPDIR/changed_paths.txt"
  awk '
    NR==FNR { pre[$1]=$2; next }
    { if (pre[$1]!=$2) print $1 }
  ' "$PRE" "$POST" > "$CHANGED_PATHS_FILE"

  if [ ! -s "$CHANGED_PATHS_FILE" ]; then
    echo "No submodule SHAs changed. Nothing to commit."
    rm -rf "$TMPDIR"
    exit 0
  fi

  echo "Submodules updated (changed):"
  cat "$CHANGED_PATHS_FILE"

  if [ "$NO_COMMIT" -eq 1 ]; then
    echo "--no-commit specified; exiting without committing."
    rm -rf "$TMPDIR"
    exit 0
  fi

  echo "Staging changed submodule entries in superproject..."
  # Stage each changed submodule path in the superproject
  while read -r p; do
    # protect against empty lines
    [ -z "$p" ] && continue
    git add -- "$p" || git add -A -- "$p" || true
  done < "$CHANGED_PATHS_FILE"

  if git diff --staged --quiet; then
    echo "No staged changes to commit after staging submodules."
    rm -rf "$TMPDIR"
    exit 0
  fi

  echo "Committing superproject with message: $MSG"
  git commit -m "$MSG"

  echo "Cleanup"
  rm -rf "$TMPDIR"

  echo "Done."

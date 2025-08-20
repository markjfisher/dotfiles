#!/bin/bash
#
# Fetch upstream changes, merge them in with ff-only to our main/master
# branch, then rebase our current work on top of that.
# Allows for different remote and/or branch names through arguments
#
# Examples
# Original behavior (defaults)
# ./upstream.sh
#
# Use different remote
#./upstream.sh -u andys-remote
#
# Target specific branch
#./upstream.sh -b develop
#
# Use different remote and branch
#./upstream.sh -u mozzs-fork -b feature-branch
#
# Show help
#./upstream.sh -h

# Default values
UPSTREAM_REMOTE="upstream"
USER_BRANCH=""
UB_SPECIFIED="false"

# Parse command line arguments
while getopts "u:b:h" opt; do
  case $opt in
    u)
      UPSTREAM_REMOTE="$OPTARG"
      ;;
    b)
      USER_BRANCH="$OPTARG"
      UB_SPECIFIED="true"
      ;;
    h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Fetch upstream changes and rebase local work on top of them."
      echo ""
      echo "Options:"
      echo "  -u <remote>        Upstream remote name (default: upstream)"
      echo "  -b <branch>        Target branch name (default: auto-detect main/master)"
      echo "  -h                 Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                 # Use defaults (upstream remote, main/master branch)"
      echo "  $0 -b develop      # Rebase against develop branch"
      echo "  $0 -u origin -b main  # Use origin remote and main branch"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Use -h for usage information"
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

if [ -n "$(git status --short)" ] ; then
  echo "Your working tree is not clean. Aborting"
  exit 1
fi

git remote | grep -s "$UPSTREAM_REMOTE" > /dev/null
if [ $? -ne 0 ] ; then
  echo "No '$UPSTREAM_REMOTE' remote found."
  echo "Please use 'git remote add $UPSTREAM_REMOTE <URL to remote git repo>' to use this"
  exit 1
fi

# main or master branch name
if [ "$UB_SPECIFIED" == "true" ] ; then
  # Use the specified branch directly
  M_BRANCH="$USER_BRANCH"
else
  # Auto-detect master/main branch
  BR_MATCH="(\bmaster\b|\bmain\b)"
  M_BRANCH=$(git branch -v --no-color | sed 's#^\*# #' | awk '{print $1}' | grep -E "$BR_MATCH" | head -1)
fi

if [ -z "$M_BRANCH" ] ; then
  if [ "$UB_SPECIFIED" == "true" ] ; then
    echo "Specified branch '$USER_BRANCH' not found locally."
  else
    echo "Could not find branch to merge against. Used pattern: $BR_MATCH"
  fi
  exit 1
fi

# Verify the branch exists locally
if [ "$UB_SPECIFIED" == "true" ] ; then
  if ! git show-ref --verify --quiet refs/heads/$M_BRANCH; then
    echo "Error: Local branch '$M_BRANCH' does not exist."
    echo "Available branches:"
    git branch --list
    exit 1
  fi
fi

# jumps to target branch if needed, fetches, merges and pushes latest changes to our
# repo, then rebases our branch on top of the branch

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "${M_BRANCH}" ]; then
  echo "Changing from branch ${current_branch} to ${M_BRANCH}"
  git checkout ${M_BRANCH}
fi

echo "Fetching $UPSTREAM_REMOTE changes"
git fetch $UPSTREAM_REMOTE ${M_BRANCH}
echo "Merging changes (fast forward only)"
git merge $UPSTREAM_REMOTE/${M_BRANCH} --ff-only
if [ $? -ne 0 ] ; then
  echo "ERROR performing ff-only merge. Rebasing against $UPSTREAM_REMOTE"
  git rebase $UPSTREAM_REMOTE/${M_BRANCH}
  if [ $? -ne 0 ] ; then
    echo "ERROR rebasing to $UPSTREAM_REMOTE. Your changes conflict with $UPSTREAM_REMOTE changes."
    git rebase --abort
    exit 1
  fi
fi

if [ "$current_branch" != "${M_BRANCH}" ]; then
  echo "Resetting back to previous branch ${current_branch}"
  git checkout $current_branch
  echo "Rebasing local changes with $UPSTREAM_REMOTE. You may need to fix merge conflicts"
  git rebase ${M_BRANCH}
fi

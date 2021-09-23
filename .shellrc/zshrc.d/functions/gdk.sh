#!/usr/bin/env bash

if [[ -d "${GDK_ROOT}" ]]; then
  function _rebase-all() {
    CURRENT_BRANCH="$(git branch --show-current)"

    DEFAULT_BRANCH='main'
    git show-ref refs/remotes/origin/master >/dev/null && DEFAULT_BRANCH='master'
    git for-each-ref --shell --format='git switch %(refname) && git rebase '"${DEFAULT_BRANCH}"' && echo -------- && '\\'' refs/heads/pedropombeiro | { sed 's;refs/heads/;;'; echo "git switch '${CURRENT_BRANCH}'"; } | bash
  }

  function rebase-all() {
    if ! git diff-index --quiet HEAD --; then
      echo 'Please stash the changes in the current branch before calling rebase-all!'
      return
    fi

    _rebase-all
  }

  function fgdku() {
    cd "${GDK_ROOT}/gitlab" || exit

    rm -rf .git/gc.log
    git checkout db/structure.sql

    if ! git diff-index --quiet HEAD --; then
      echo 'Please stash the changes in the current branch before calling fgdku!'
      cd - >/dev/null
      return
    fi

    set -e
    echo "Updating GDK..."
    gdk update

    git checkout db/structure.sql
		sleep 5

    echo "Running simple test..."
    bin/rspec spec/lib/gitlab/ci/variables/collection_spec.rb
    set +e

    echo "Pruning local branches..."
    git prune-branches

    echo "Rebasing local branches..."
    _rebase-all
    echo "Done."

    cd - >/dev/null
  }
fi

function thin-clone() {
  set -o pipefail

  POSTGRES_AI_HOST='gitlab-joe-poc.postgres.ai'
  case $1 in
    create)
      echo -n "Username (defaults to '${USER}'): "
      read -r USERNAME
      echo
      if [[ -z ${USERNAME} ]]; then
        USERNAME="${USER}"
      fi

      PASSENTRY="$(grep "localhost:10000:gitlabhq_dblab:${USERNAME}" ~/.pgpass)"
      if [[ -z ${PASSENTRY} ]]; then
        # Generate random password
        PASSWORD="$(openssl rand -base64 20)"
        export PGPASSWORD="${PASSWORD}"
      else
        echo "Found entry in ~/.pgpass for ${USERNAME}"
        PASSWORD=$(echo "${PASSENTRY}" | awk -F "\"*:\"*" '{print $5}')
      fi

      echo "Starting a tunnel to ${POSTGRES_AI_HOST}"
      ssh dblab-joe -f -N

      echo "Creating thin clone for ${USERNAME}..."
      PORT="$(dblab clone create --username "${USERNAME}" --password "${PASSWORD}" | jq -r '.db.port')"
      LOCAL_PORT=10000

      echo "Forwarding local port (${LOCAL_PORT}) to the returned port (${PORT}) at ${POSTGRES_AI_HOST}"
      ssh -L "${LOCAL_PORT}:localhost:${PORT}" -f -N "gldatabase@${POSTGRES_AI_HOST}"

      echo "Connecting psql to the local port (${LOCAL_PORT}) with random password ${PASSWORD}"
      export PAGER='less -RS'
      psql -h localhost -p "${LOCAL_PORT}" -U "${USERNAME}" gitlabhq_dblab --set="PROMPT1=%/ on :${PORT}%R%#"
      ;;
    list)
      echo -n "Username (defaults to '${USER}'): "
      read -r USERNAME
      echo
      if [[ -z ${USERNAME} ]]; then
        USERNAME="${USER}"
      fi

      echo "Listing thin clones for ${USERNAME}"
      dblab instance status | jq --arg username "${USERNAME}" -r '.clones[] | select(.db.username == $username) | .id'
      ;;
    destroy-all)
      echo -n "Username (defaults to '${USER}'): "
      read -r USERNAME
      echo
      if [[ -z ${USERNAME} ]]; then
        USERNAME="${USER}"
      fi

      echo "Listing thin clones for ${USERNAME}"
      IDS=( $(dblab instance status | jq --arg username "${USERNAME}" -r '.clones[] | select(.db.username == $username) | .id') )
      for id in "${IDS[@]}"; do
        echo "Destroying clone ${id}..."
        dblab clone destroy -a "${id}"
      done
      ;;
    stop-ssh)
      echo 'Stopping SSH processes...'
      ps aux | grep ssh | grep '\-joe' | awk '{print $2}' | xargs kill -9 || echo -n
      ;;
    *)
      echo "Unknown command '$1', aborting"
      ;;
  esac

  echo Done
}

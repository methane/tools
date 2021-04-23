
# Firs figure out $LOCAL_BENCH_USER
scriptfile=${BASH_SOURCE[0]}
if [ -z "$scriptfile" ]; then
    >&2 echo "this file should only be sourced"
    exit 1
fi
LOCAL_BENCH_DIR="$(dirname $scriptfile)"
homedir="$(dirname $LOCAL_BENCH_DIR)"
if [ "$(dirname $homedir)" != "/home" ]; then
    # XXX Try relative to the repo instead?
    >&2 echo "something went terribly wrong with $scriptfile"
    return 1
fi
if [ "$(basename $LOCAL_BENCH_DIR)" = '.bench' ]; then
    LOCAL_BENCH_DIR="$homedir/BENCH"
fi
LOCAL_BENCH_USER="$(basename $homedir)"
if [ -n "$USER" -a "$USER" = "$LOCAL_BENCH_USER" ]; then
    >&2 echo "$scriptfile is not meant to be used by $LOCAL_BENCH_USER"
    return 1
fi
homedir=
scriptfile=

local_config=
portal_config="$LOCAL_BENCH_DIR/portal.json"
bench_config="$LOCAL_BENCH_DIR/bench.json"
if [ -e "$portal_config" ]; then
    local_config=$portal_config
    BENCH_USER="$(sudo jq -r '.send_user' $portal_config)"
    BENCH_HOST="$(sudo jq -r '.send_host' $portal_config)"
    BENCH_PORT="$(sudo jq -r '.send_port' $portal_config)"
    BENCH_CONN="$BENCH_USER@$BENCH_HOST"
elif [ -e "$bench_config" ]; then
    local_config=$bench_config
    PORTAL_USER="$(sudo jq -r '.portal_user' $bench_config)"
    PORTAL_HOST="$(sudo jq -r '.portal_host' $bench_config)"
    PORTAL_PORT="$(sudo jq -r '.portal_port' $bench_config)"
    PORTAL_CONN="$PORTAL_USER@$PORTAL_HOST"
fi

GIT_AUTHOR_NAME="$(git config --global --get 'user.name')"
GIT_AUTHOR_EMAIL="$(git config --global --get 'user.email')"
GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"


function bench-fix-ssh-agent() {
    if [ -z "$SSH_AUTH_SOCK" ]; then
        >&2 echo "WARNING: no SSH agent running!"
        >&2 echo "(one is required in order to use the bench host)"
        >&2 echo "(be sure to run 'bench-fix-ssh-agent' after starting an SSH agent)"
    else
        echo "fixing permissions on \$SSH_AUTH_SOCK so it can be used by the '$LOCAL_BENCH_USER' user..."

        local agent_dir=$(dirname "$SSH_AUTH_SOCK")
        ( set -x; setfacl -m $LOCAL_BENCH_USER:x $agent_dir; )
        ( set -x; setfacl -m $LOCAL_BENCH_USER:rwx "$SSH_AUTH_SOCK"; )
        echo "...done!"
    fi
}


##################################
# set up for using the bench host

echo
echo '==================================='
echo '=== setting up for benchmarking ==='
echo '==================================='

# Set up common aliases.
echo
set -x
alias bench-home='sudo --login --user $LOCAL_BENCH_USER \
    SUDO_PWD="$(pwd)" \
    SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
    GIT_AUTHOR_NAME="$GIT_AUTHOR_NAME" \
    GIT_AUTHOR_EMAIL="$GIT_AUTHOR_EMAIL" \
    GIT_COMMITTER_NAME="$GIT_COMMITTER_NAME" \
    GIT_COMMITTER_EMAIL="$GIT_COMMITTER_EMAIL" \
'
# Use of $PWD_INIT assumes the following code in ~$LOCAL_BENCH_USER/.profile:
#  if [ -n "$PWD_INIT" ]; then
#      cd $PWD_INIT
#  fi
alias bench-cwd='bench-home PWD_INIT="$(pwd)"'
alias bench-git='bench-cwd git'
{ set +x; } 2>/dev/null

function bench() {
    case "$(realpath $(pwd))" in
        /home/$LOCAL_BENCH_USER|/home/$LOCAL_BENCH_USER/)
            bench-home "$@"
            ;;
        /home/$LOCAL_BENCH_USER/*)
            bench-cwd "$@"
            ;;
        *)
            bench-home "$@"
            ;;
    esac
}
echo 'added bash function "bench" that combines bench-home and bench-cwd'

# Set up host-specific aliases.
if [ "$local_config" = "$portal_config" ]; then
    set -x
    alias bench-ssh="bench ssh -p $BENCH_PORT $BENCH_CONN"
    alias bench-scp="bench scp -P $BENCH_PORT"
    { set +x; } 2>/dev/null
fi

echo
bench-fix-ssh-agent

echo
echo "env vars:"
echo
echo "LOCAL_BENCH_USER: $LOCAL_BENCH_USER"
echo "LOCAL_BENCH_DIR:  $LOCAL_BENCH_DIR"
if [ "$local_config" = "$portal_config" ]; then

echo "BENCH_USER:       $BENCH_USER"
echo "BENCH_HOST:       $BENCH_HOST"
echo "BENCH_PORT:       $BENCH_PORT"
echo "BENCH_CONN:       $BENCH_CONN"

elif [ "$local_config" = "$bench_config" ]; then

echo "PORTAL_USER:      $PORTAL_USER"
echo "PORTAL_HOST:      $PORTAL_HOST"
echo "PORTAL_PORT:      $PORTAL_PORT"
echo "PORTAL_CONN:      $PORTAL_CONN"

fi
echo
echo '==================================='
echo '===   done (for benchmarking)   ==='
echo '==================================='
echo

local_config=
portal_config=
bench_config=

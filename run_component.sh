#!/bin/bash
USAGE=$(cat <<EOF
A simple script that allows for the execution of a component on the workspace container.
Usage: run.sh path/to/playbook.yml
Will:
1. Check for the presence of a requirements.yml in the same location as the playbook file, and install it.
2. Run the playbook.

If component_vars.yml exists in the same directory as the playbook, these variables will be passed along to Ansible.
EOF
)

set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 1 ]]; then
    echo "$USAGE"
    exit 1
fi

PLAYBOOK="$1"
PLAYBOOK_DIR="$(dirname "$PLAYBOOK")"
REQUIREMENTS="$PLAYBOOK_DIR/requirements.yml"
VARS="$PLAYBOOK_DIR/component_vars.yml"

if [[ -e "$REQUIREMENTS" ]]; then
    echo "Found $REQUIREMENTS..."
    echo "Installing $REQUIREMENTS using ansible-galaxy"
    ansible-galaxy collection install -r "$REQUIREMENTS"
else
    echo "Did not find a requirements file in $REQUIREMENTS!"
fi

if [[ -e "$VARS" ]]; then
    echo "Found variables file $VARS"
    EXTRA_VARS="-e \"@$VARS\""
else
    EXTRA_VARS=""
fi

export ANSIBLE_STDOUT_CALLBACK="yaml"
export ANSIBLE_FORCE_COLOR="True"

CMD="ansible-playbook -i localhost, -c local -vv $EXTRA_VARS $PLAYBOOK"
echo "Running command: $CMD"
eval "$CMD"
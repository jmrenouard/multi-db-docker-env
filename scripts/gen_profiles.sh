#!/bin/bash

# Configuration
REPLI_PROFILE="profile_repli"
GALERA_PROFILE="profile_galera"
USER="root"
PASS="rootpass"

echo "=========================================================="
echo "🐚 Generating Shell Profiles and Aliases"
echo "=========================================================="

# Ensure proper permissions for SSH key
if [ -f "./id_rsa" ]; then
    chmod 600 "./id_rsa"
    echo "🔐 SSH key permissions set to 600."
fi

# --- Replication Profile ---
cat << EOF > $REPLI_PROFILE
# Replication Environment Aliases
# Source this file: source $REPLI_PROFILE

alias mariadb-m1='mariadb -h 127.0.0.1 -P 3411 -u$USER -p$PASS'
alias mariadb-s1='mariadb -h 127.0.0.1 -P 3412 -u$USER -p$PASS'
alias mariadb-s2='mariadb -h 127.0.0.1 -P 3413 -u$USER -p$PASS'
alias mariadb-repli-lb-rw='mariadb -h 127.0.0.1 -P 3406 -u$USER -p$PASS'
alias mariadb-repli-lb-ro='mariadb -h 127.0.0.1 -P 3407 -u$USER -p$PASS'
alias ssh-m1='ssh -i ./id_rsa -p 23001 root@127.0.0.1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
alias ssh-s1='ssh -i ./id_rsa -p 23002 root@127.0.0.1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
alias ssh-s2='ssh -i ./id_rsa -p 23003 root@127.0.0.1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

echo "✅ Replication aliases loaded (mariadb-m1, mariadb-s1, mariadb-s2, mariadb-repli-lb-rw, mariadb-repli-lb-ro, ssh-m1, ssh-s1, ssh-s2)"
EOF

# --- Galera Profile ---
cat << EOF > $GALERA_PROFILE
# Galera Environment Aliases
# Source this file: source $GALERA_PROFILE

alias mariadb-g1='mariadb -h 127.0.0.1 -P 3511 -u$USER -p$PASS'
alias mariadb-g2='mariadb -h 127.0.0.1 -P 3512 -u$USER -p$PASS'
alias mariadb-g3='mariadb -h 127.0.0.1 -P 3513 -u$USER -p$PASS'
alias mariadb-galera-lb='mariadb -h 127.0.0.1 -P 3306 -u$USER -p$PASS'
alias ssh-g1='ssh -i ./id_rsa -p 22001 root@127.0.0.1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
alias ssh-g2='ssh -i ./id_rsa -p 24002 root@127.0.0.1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
alias ssh-g3='ssh -i ./id_rsa -p 24003 root@127.0.0.1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

echo "✅ Galera aliases loaded (mariadb-g1, mariadb-g2, mariadb-g3, mariadb-galera-lb, ssh-g1, ssh-g2, ssh-g3)"
EOF

chmod +x $REPLI_PROFILE $GALERA_PROFILE
echo "✨ Profiles generated: $REPLI_PROFILE, $GALERA_PROFILE"
echo "👉 Use 'source <profile_name>' to activate them."

#!/bin/bash
# entrypoint_etcd.sh
# Gère le démarrage dynamique d'ETCD (new vs existing) pour assurer la HA.

# Détection de l'état du cluster
STATE="new"
if [ -d "${ETCD_DATA_DIR}/member" ]; then
    echo "🔄 Répertoire de données détecté. Passage en état 'existing'."
    STATE="existing"
fi

# Pour éviter le conflit entre variables d'environnement et flags (ETCD 3.6+)
SAVED_DATA_DIR="${ETCD_DATA_DIR}"
SAVED_NAME="${ETCD_NAME}"
unset ETCD_DATA_DIR
unset ETCD_NAME
unset ETCD_LISTEN_CLIENT_URLS
unset ETCD_ADVERTISE_CLIENT_URLS
unset ETCD_LISTEN_PEER_URLS
unset ETCD_INITIAL_ADVERTISE_PEER_URLS
unset ETCD_INITIAL_CLUSTER
unset ETCD_INITIAL_CLUSTER_TOKEN
unset ETCD_INITIAL_CLUSTER_STATE

# Construction des arguments de sécurité
AUTH_FLAGS=""
if [ "${VERIFY_CLIENT_CERT}" = "true" ]; then
    AUTH_FLAGS="--peer-client-cert-auth"
fi

# Démarrage du service SSH pour la gestion Ansible
/usr/sbin/sshd

# Construction de la commande ETCD avec les variables d'environnement
# Exécution d'ETCD
/usr/bin/etcd \
    --name "${SAVED_NAME}" \
    --data-dir "${SAVED_DATA_DIR}" \
    --listen-client-urls "https://0.0.0.0:${INT_ETCD_CLIENT_PORT}" \
    --advertise-client-urls "https://${SAVED_NAME}:${INT_ETCD_CLIENT_PORT}" \
    --listen-peer-urls "https://0.0.0.0:${INT_ETCD_PEER_PORT}" \
    --initial-advertise-peer-urls "https://${SAVED_NAME}:${INT_ETCD_PEER_PORT}" \
    --initial-cluster "etcd1=https://etcd1:${INT_ETCD_PEER_PORT},etcd2=https://etcd2:${INT_ETCD_PEER_PORT},etcd3=https://etcd3:${INT_ETCD_PEER_PORT}" \
    --initial-cluster-token "etcd-cluster-1" \
    --initial-cluster-state "${STATE}" \
    --cert-file "/certs/etcd-server.crt" \
    --key-file "/certs/etcd-server.key" \
    --trusted-ca-file "/certs/ca.crt" \
    --peer-cert-file "/certs/etcd-server.crt" \
    --peer-key-file "/certs/etcd-server.key" \
    --peer-trusted-ca-file "/certs/ca.crt" \
    $AUTH_FLAGS || { echo "⚠️ ETCD a échoué. Maintien du conteneur..."; tail -f /dev/null; }

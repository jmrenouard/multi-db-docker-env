FROM mariadb:11.8

# Définition des variables d'environnement pour éviter les interactions lors de l'install
ENV DEBIAN_FRONTEND=noninteractive \
  TERM=xterm 

# 🛠️ Installation des utilitaires système, SSH et Supervisor
# Ajout de 'clean' pour réduire la taille de l'image
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  openssh-server \
  openssl \
  supervisor \
  rsync \
  vim \
  nano \
  htop \
  iotop \
  net-tools \
  percona-toolkit \
  sysbench \
  pigz \
  wget \
  screen \
  curl \
  git \
  unzip \
  ca-certificates && \
  mkdir -p /var/run/sshd /var/log/supervisor /exemples /datas && \
  # Nettoyage des caches apt pour réduire la taille de l'image
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 🔐 Configuration SSH (Mot de passe root - À utiliser pour DEV uniquement)
# Note: Pour la prod, privilégier les clés SSH
RUN echo 'root:rootpass' | chpasswd && \
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ⚙️ Configuration
# On copie le script de démarrage conditionnel de MariaDB
COPY start-mariadb.sh /usr/local/bin/start-mariadb.sh
RUN chmod +x /usr/local/bin/start-mariadb.sh

# Copie de la configuration Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Ports exposés
EXPOSE 22 3306

# Volumes et Dossier de travail
VOLUME ["/datas"]
WORKDIR /datas

# 1. Création du dossier .ssh
# 2. Copie de la clé publique depuis le contexte de build vers l'image
# 3. Application des permissions STRICTES (Indispensable pour SSH)

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

COPY id_rsa.pub /root/.ssh/authorized_keys
COPY id_rsa.pub /root/.ssh/id_rsa.pub
COPY id_rsa /root/.ssh/id_rsa

RUN chmod 600 /root/.ssh/authorized_keys /root/.ssh/id_rsa \
  && chown -R root:root /root/.ssh

# Démarrage via Supervisor qui gère SSH et MariaDB
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

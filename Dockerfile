FROM mariadb:11.8

# Define environment variables to avoid interactions during installation
ENV DEBIAN_FRONTEND=noninteractive \
  TERM=xterm 

# 🛠️ Installation of system utilities, SSH, and Supervisor
# Added 'clean' to reduce image size
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
  # Cleaning up apt caches to reduce image size
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 🔐 SSH Configuration
# Note: Credentials and keys are NOT baked into the image.
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# ⚙️ Configuration
# Copying the MariaDB conditional startup script
COPY scripts/start_mariadb.sh /usr/local/bin/start_mariadb.sh
RUN chmod +x /usr/local/bin/start_mariadb.sh

# Copying Supervisor configuration
COPY conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Exposed ports
EXPOSE 22 3306

# Volumes and Working Directory
VOLUME ["/datas"]
WORKDIR /datas

# 🔐 SSH Service & Key Directory Setup
# Host keys are generated, and /root/.ssh is secured with strict permissions.
# Public keys should be mounted at runtime (e.g. -v ./id_rsa.pub:/root/.ssh/authorized_keys:ro).
RUN ssh-keygen -A && \
  mkdir -p /root/.ssh && \
  chmod 700 /root/.ssh

# Startup via Supervisor which manages SSH and MariaDB
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

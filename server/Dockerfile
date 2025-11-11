FROM ubuntu:22.04

# Set environment variables
ENV GIT_USER=git
ENV REPO_PATH=/home/git/repositories
ENV SSH_PORT=22
ARG GIT_UID=1000
ARG GIT_GID=1000

# Install required packages
RUN apt-get update && apt-get install -y \
    git \
    openssh-server \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create git & group

RUN groupadd -g ${GIT_GID} git || true && \
    useradd -m -u ${GIT_UID} -g ${GIT_GID} -s /bin/bash git

# Setup SSH directory and configuration
RUN mkdir -p /home/git/.ssh && \
    chown -R git:git /home/git/.ssh && \
    chmod 700 /home/git/.ssh && \
    mkdir -p /var/run/sshd

# Use persisted host keys
# RUN sed -i '/^HostKey/d' /etc/ssh/sshd_config && \
#     echo 'HostKey /etc/ssh/keys/ssh_host_ed25519_key' >> /etc/ssh/sshd_config

# Configure SSH server
RUN sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    grep -q '^PubkeyAuthentication yes' /etc/ssh/sshd_config || echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    grep -q '^AuthorizedKeysFile .ssh/authorized_keys' /etc/ssh/sshd_config || echo 'AuthorizedKeysFile .ssh/authorized_keys' >> /etc/ssh/sshd_config

    # Create repositories directory
RUN mkdir -p /home/git/repositories && \
    chown -R git:git /home/git/repositories

# Create scripts directory
RUN mkdir -p /home/git/scripts && \
    chown -R git:git /home/git/scripts

    # Git defaults
RUN git config --system init.defaultBranch main && \
    git config --system user.name "UNF Automations" && \
    git config --system user.email "technology@unnamedco.com"

    #Scripts
COPY ./scripts/ /home/git/scripts/
RUN chmod +x /home/git/scripts/*.sh && chown -R git:git /home/git/scripts



# Expose SSH port
EXPOSE ${SSH_PORT}

# Start SSH server
CMD ["/usr/sbin/sshd", "-D"] 
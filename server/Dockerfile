FROM ubuntu:22.04

# Set environment variables
ENV GIT_USER=git
ENV REPO_PATH=/home/git/repositories
ENV SSH_PORT=22

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
COPY create-repo.sh add-user.sh inspect-repos.sh update-gitignore.sh gitignore-template /home/git/scripts/
RUN chmod +x /home/git/scripts/*.sh && chown -R git:git /home/git/scripts



# Expose SSH port
EXPOSE ${SSH_PORT}

# Start SSH server
CMD ["/usr/sbin/sshd", "-D"] 
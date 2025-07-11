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

# Create git user
RUN useradd -m -s /bin/bash git && \
    echo 'git:gitpass' | chpasswd

# Setup SSH directory and configuration
RUN mkdir -p /home/git/.ssh && \
    chown -R git:git /home/git/.ssh && \
    chmod 700 /home/git/.ssh && \
    mkdir -p /var/run/sshd

# Configure SSH server
RUN echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'AuthorizedKeysFile .ssh/authorized_keys' >> /etc/ssh/sshd_config && \
    echo 'PermitRootLogin no' >> /etc/ssh/sshd_config

# Create repositories directory
RUN mkdir -p /home/git/repositories && \
    chown -R git:git /home/git/repositories

# Create scripts directory
RUN mkdir -p /home/git/scripts && \
    chown -R git:git /home/git/scripts

# Copy server scripts to the container
COPY create-repo.sh /home/git/scripts/
COPY add-user.sh /home/git/scripts/
COPY inspect-repos.sh /home/git/scripts/
COPY update-gitignore.sh /home/git/scripts/
COPY gitignore-template /home/git/scripts/

# Make scripts executable
RUN chmod +x /home/git/scripts/*.sh && \
    chown -R git:git /home/git/scripts

# Expose SSH port
EXPOSE 22

# Start SSH server
CMD ["/usr/sbin/sshd", "-D"] 
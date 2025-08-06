FROM jenkins/jenkins:2.452.1-lts

# Switch to root for installations
USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Install uv globally
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

# Create cache directories
RUN mkdir -p /var/jenkins_cache/uv && chown -R jenkins:jenkins /var/jenkins_cache

# Switch back to jenkins user
USER jenkins

# Install plugins from file
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

# JCasC configuration will be mounted from ConfigMap at runtime
# Create casc_configs directory for mounted configurations
RUN mkdir -p /var/jenkins_home/casc_configs
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/

# Skip setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Expose metrics endpoint
EXPOSE 8080 50000 9090
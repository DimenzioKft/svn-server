FROM debian:bookworm-slim

# Install Apache, SVN and tools
RUN apt-get update && apt-get install -y \
    apache2 \
    apache2-utils \
    subversion \
    libapache2-mod-svn \
    curl \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache modules
RUN a2enmod rewrite \
    && a2enmod dav \
    && a2enmod dav_svn \
    && a2enmod authz_user \
    && a2enmod auth_digest

# Create SVN directory
RUN mkdir -p /var/svn

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Expose HTTP port only
EXPOSE 80

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

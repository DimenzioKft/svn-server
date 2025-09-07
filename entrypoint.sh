#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting SVN Server initialization...${NC}"

# Set default values if environment variables are not set
SVN_ADMIN_USER=${SVN_ADMIN_USER:-admin}
SVN_ADMIN_PASSWORD=${SVN_ADMIN_PASSWORD:-changeme123}
APACHE_SERVER_NAME=${APACHE_SERVER_NAME:-svn.localhost}

# Create SVN repository if it doesn't exist
if [ ! -d "/var/svn/repository" ]; then
    echo -e "${YELLOW}Creating SVN repository...${NC}"
    svnadmin create /var/svn/repository
    chown -R www-data:www-data /var/svn/repository
    echo -e "${GREEN}SVN repository created successfully${NC}"
else
    echo -e "${YELLOW}SVN repository already exists${NC}"
fi

# Create htpasswd file if it doesn't exist
if [ ! -f "/var/svn/.htpasswd" ]; then
    echo -e "${YELLOW}Creating user authentication file...${NC}"
    htpasswd -cb /var/svn/.htpasswd "$SVN_ADMIN_USER" "$SVN_ADMIN_PASSWORD"
    echo -e "${GREEN}Admin user created: $SVN_ADMIN_USER${NC}"
else
    echo -e "${YELLOW}Authentication file already exists${NC}"
fi

# Create authz.conf if it doesn't exist
if [ ! -f "/var/svn/authz.conf" ]; then
    echo -e "${YELLOW}Creating authorization file...${NC}"
    cat > /var/svn/authz.conf << EOF
[groups]
admins = $SVN_ADMIN_USER

[/]
@admins = rw
* = r

[repository:/]
@admins = rw
* = r
EOF
    echo -e "${GREEN}Authorization file created${NC}"
fi

# Set proper permissions
chown -R www-data:www-data /var/svn
chmod -R 755 /var/svn

# Create a simple index page
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SVN Server</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>SVN Server</h1>
    <p>Welcome to your SVN server!</p>
    <ul>
        <li><a href="/svn/">Browse Repositories</a></li>
        <li><strong>SVN URL:</strong> http://$APACHE_SERVER_NAME:8080/svn/repository</li>
        <li><strong>Note:</strong> SSL is handled by nginx proxy manager</li>
    </ul>
    
    <h2>Usage Examples:</h2>
    <pre>
# Checkout repository (through proxy)
svn checkout https://your-domain.com/svn/repository

# Or direct access (development)
svn checkout http://$APACHE_SERVER_NAME:8080/svn/repository

# Add files
svn add file.txt
svn commit -m "Added file.txt"

# Update
svn update
    </pre>
</body>
</html>
EOF

echo -e "${GREEN}SVN Server initialization completed!${NC}"
echo -e "${YELLOW}Admin user: $SVN_ADMIN_USER${NC}"
echo -e "${YELLOW}Internal URL: http://$APACHE_SERVER_NAME:8080/svn/repository${NC}"
echo -e "${YELLOW}Configure nginx proxy manager to handle SSL${NC}"
echo -e "${RED}Don't forget to change the default password!${NC}"

# Start Apache in foreground
echo -e "${GREEN}Starting Apache...${NC}"
exec apache2ctl -D FOREGROUND

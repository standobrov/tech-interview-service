#!/bin/bash

# Exit on error
set -e

# Word lists for username generation
names=(
    "hungry" "sleepy" "angry" "sad" "happy" "excited" "bored" "tired" "sick"
)

surnames=(
    "naruto" "sasuke" "sakura" "kakashi" "jiraiya" "tsunade" "orochimaru" "itachi" "madara" "obito"
    "shikamaru" "choji" "ino" "neji" "rocklee" "gaara" "temari" "kankuro" "hinata"
    "minato" "deidara" "kisame" "pain"
)

# Generate random username from words
random_name=${names[$RANDOM % ${#names[@]}]}
random_surname=${surnames[$RANDOM % ${#surnames[@]}]}
SSH_USER="${random_name}_${random_surname}"
SSH_PASS="$(openssl rand -base64 12)"

# Define user names
ADMIN_USER="interview_user"
SERVICE_USER="interview_service_user"

echo "Generated SSH credentials:"
echo "Username: $SSH_USER"
echo "Password: $SSH_PASS"
echo "Please save these credentials!"

# Update system packages
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required system packages
echo "Installing required system packages..."
sudo apt-get install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib

# Create SSH user (can connect via SSH, has sudo rights)
echo "Creating SSH user..."
sudo useradd -m -s /bin/bash "$SSH_USER"
echo "$SSH_USER:$SSH_PASS" | sudo chpasswd
sudo usermod -aG sudo "$SSH_USER"

# Create admin user (can't connect via SSH, has sudo rights)
echo "Creating admin user..."
sudo useradd -m -s /bin/bash "$ADMIN_USER"
echo "$ADMIN_USER:$(openssl rand -base64 12)" | sudo chpasswd
sudo usermod -aG sudo "$ADMIN_USER"
# Prevent SSH access
sudo chsh -s /bin/false "$ADMIN_USER"

# Create service user (can't connect via SSH, no sudo rights)
echo "Creating service user..."
sudo useradd -r -s /bin/false "$SERVICE_USER"
sudo mkdir -p /opt/app
sudo chown "$SERVICE_USER:$SERVICE_USER" /opt/app

# Copy application files
echo "Copying application files..."
sudo -u "$SERVICE_USER" cp -r backend binance_service frontend init.sql init-db.sh /opt/app/

# Create credentials directory and file
echo "Setting up credentials..."
sudo mkdir -p /etc/tech-interview-stand
echo "postgresql://$SERVICE_USER:interview_password@localhost:5432/interview_db" | sudo tee /etc/tech-interview-stand/db-url > /dev/null
sudo chmod 600 /etc/tech-interview-stand/db-url
sudo chown root:root /etc/tech-interview-stand/db-url

# Create and activate Python virtual environment
echo "Setting up Python virtual environment..."
cd /opt/app
sudo -u "$SERVICE_USER" python3 -m venv venv
sudo -u "$SERVICE_USER" /opt/app/venv/bin/pip install -r backend/requirements.txt

# Set up PostgreSQL
echo "Setting up PostgreSQL..."
sudo -u postgres psql -c "CREATE USER $SERVICE_USER WITH PASSWORD 'interview_password';"
sudo -u postgres psql -c "CREATE DATABASE interview_db;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE interview_db TO $SERVICE_USER;"

# Initialize database
echo "Initializing database..."
sudo -u "$SERVICE_USER" psql -U "$SERVICE_USER" -d interview_db -f init.sql

# Copy systemd service files
echo "Setting up systemd services..."
sudo cp systemd/interview-backend.service /etc/systemd/system/tech-interview-stand-api.service
sudo cp systemd/interview-binance.service /etc/systemd/system/tech-interview-stand-worker.service

# Update service files to use service user
sudo sed -i "s/User=.*/User=$SERVICE_USER/" /etc/systemd/system/tech-interview-stand-api.service
sudo sed -i "s/Group=.*/Group=$SERVICE_USER/" /etc/systemd/system/tech-interview-stand-api.service
sudo sed -i "s/User=.*/User=$SERVICE_USER/" /etc/systemd/system/tech-interview-stand-worker.service
sudo sed -i "s/Group=.*/Group=$SERVICE_USER/" /etc/systemd/system/tech-interview-stand-worker.service

# Set up nginx
echo "Setting up nginx..."
sudo cp frontend/nginx.conf /etc/nginx/sites-available/tech-interview-stand
sudo ln -sf /etc/nginx/sites-available/tech-interview-stand /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo mkdir -p /var/www/tech-interview-stand
sudo cp -r frontend/* /var/www/tech-interview-stand/
sudo chown -R www-data:www-data /var/www/tech-interview-stand

# Reload systemd and start services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable tech-interview-stand-api
sudo systemctl enable tech-interview-stand-worker
sudo systemctl start tech-interview-stand-api
sudo systemctl start tech-interview-stand-worker
sudo systemctl restart nginx

echo "Deployment completed successfully!"
echo "You can check service status with:"
echo "sudo systemctl status tech-interview-stand-api"
echo "sudo systemctl status tech-interview-stand-worker"
echo "sudo systemctl status nginx"
echo ""
echo "IMPORTANT: SSH credentials (save them!):"
echo "Username: $SSH_USER"
echo "Password: $SSH_PASS"
echo ""
echo "User roles:"
echo "1. $SSH_USER - SSH user with sudo rights"
echo "2. $ADMIN_USER - Admin user (use 'su' to switch, no SSH access)"
echo "3. $SERVICE_USER - Service user (no SSH access, no sudo rights)" 
#!/bin/bash

# Exit on error
#set -e

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
ADMIN_PASS="$(openssl rand -base64 12)"
SERVICE_USER="interview_service_user"

echo "Generated SSH credentials:"
echo "Username: $SSH_USER"
echo "Password: $SSH_PASS"
echo "Please save these credentials!"

# Update system packages
echo "Updating system packages..."
sudo apt-get update
# sudo apt-get upgrade -y

# Install required system packages
echo "Installing required system packages..."
sudo apt-get install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib git

# Create SSH user (can connect via SSH, has sudo rights)
echo "Creating SSH user..."
sudo useradd -m -s /bin/bash "$SSH_USER"
echo "$SSH_USER:$SSH_PASS" | sudo chpasswd
sudo usermod -aG sudo "$SSH_USER"

# Create admin user (can't connect via SSH, has sudo rights)
echo "Creating admin user..."
sudo useradd -m -s /bin/bash "$ADMIN_USER"
echo "$ADMIN_USER:$ADMIN_PASS" | sudo chpasswd
sudo usermod -aG sudo "$ADMIN_USER"

# Prevent SSH access for interview_user
echo "DenyUsers $ADMIN_USER" | sudo tee /etc/ssh/sshd_config.d/deny_interview_user.conf > /dev/null
sudo systemctl restart sshd

# Create service user (can't connect via SSH, no sudo rights)
echo "Creating service user..."
sudo useradd -r -s /bin/false "$SERVICE_USER"
sudo mkdir -p /opt/app
sudo chown "$SERVICE_USER:$SERVICE_USER" /opt/app

# Clone repository
echo "Cloning repository..."
cd /opt/app
sudo -u "$SERVICE_USER" git clone http://demo:demo123@localhost:3000/demo/interview-service.git
sudo chown -R "$SERVICE_USER:$SERVICE_USER" /opt/app/interview-service

# Create credentials directory and file
echo "Setting up credentials..."
sudo mkdir -p /etc/tech-interview-stand
echo "postgresql://$SERVICE_USER:interview_password@localhost:5432/interview_db" | sudo tee /etc/tech-interview-stand/db-url > /dev/null
sudo chmod 600 /etc/tech-interview-stand/db-url
sudo chown root:root /etc/tech-interview-stand/db-url

# Create and activate Python virtual environment
echo "Setting up Python virtual environment..."
cd /opt/app/interview-service
sudo -u "$SERVICE_USER" python3 -m venv venv
sudo -u "$SERVICE_USER" /opt/app/interview-service/venv/bin/pip install -r requirements.txt

# Set up PostgreSQL
echo "Setting up PostgreSQL..."
sudo -u postgres psql -c "CREATE USER $SERVICE_USER WITH PASSWORD 'interview_password';"
sudo -u postgres psql -c "CREATE DATABASE interview_db;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE interview_db TO $SERVICE_USER;"
sudo -u postgres psql -d interview_db -c "GRANT ALL ON SCHEMA public TO $SERVICE_USER;"

# Initialize database
echo "Initializing database..."
sudo -u "$SERVICE_USER" psql -U "$SERVICE_USER" -d interview_db -f database/init.sql

# Copy systemd service files
echo "Setting up systemd services..."
sudo cp /opt/app/interview-service/systemd/interview-backend.service /etc/systemd/system/tech-interview-stand-backend.service
sudo cp /opt/app/interview-service/systemd/interview-binance.service /etc/systemd/system/tech-interview-stand-binance.service

# Update service files to use service user
sudo sed -i "s/User=.*/User=$SERVICE_USER/" /etc/systemd/system/tech-interview-stand-backend.service
sudo sed -i "s/Group=.*/Group=$SERVICE_USER/" /etc/systemd/system/tech-interview-stand-backend.service
sudo sed -i "s/User=.*/User=$SERVICE_USER/" /etc/systemd/system/tech-interview-stand-binance.service
sudo sed -i "s/Group=.*/Group=$SERVICE_USER/" /etc/systemd/system/tech-interview-stand-binance.service

# Set up nginx
echo "Setting up nginx..."
sudo cp /opt/app/interview-service/frontend/nginx.conf /etc/nginx/sites-available/tech-interview-stand
sudo ln -sf /etc/nginx/sites-available/tech-interview-stand /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo mkdir -p /var/www/tech-interview-stand
sudo cp -r /opt/app/interview-service/frontend/* /var/www/tech-interview-stand/
sudo chown -R www-data:www-data /var/www/tech-interview-stand

# Generate help.sh with actual credentials
echo "Generating help.sh..."
cat > /tmp/help.sh <<EOF
#!/bin/bash

echo "🔑 Your SSH Credentials"
echo "======================"
echo "Username: $SSH_USER"
echo "Password: $SSH_PASS"
echo

echo "🗄️ Database Credentials"
echo "======================"
echo "Database: interview_db"
echo "Username: $SERVICE_USER"
echo "Password: interview_password"
echo "Host: localhost"
echo "Port: 5432"
echo "Connection string: postgresql://$SERVICE_USER:interview_password@localhost:5432/interview_db"
echo

echo "⚠️  Troubleshooting Access"
echo "========================"
echo "For troubleshooting, switch to user $ADMIN_USER"
echo "   Password: $ADMIN_PASS"
echo
echo "This user has sudo rights and is intended for system maintenance."
echo

echo "🔧 System Information"
echo "==================="
echo "1. Dashboard frontendn (Nginx)"
echo "   - Serves static files"
echo "   - Proxies API requests to backend"
echo "   - Systemd unit: nginx.service"
echo
echo "2. Backend (FastAPI)"
echo "   - Port: 8000"
echo "   - Endpoints:"
echo "     * GET /api/trades - List all trades"
echo "     * GET /api/trades?limit=N - List N latest trades"
echo "   - Systemd unit: tech-interview-stand-backend.service"
echo
echo "3. Binance Service"
echo "   - Fetches trades from Binance API"
echo "   - Transforms data and adds "suspicious" flag"
echo "   - Saves trades to PostgreSQL database"
echo "   - Systemd unit: tech-interview-stand-binance.service"
echo

echo "🗄️ Database Structure"
echo "==================="
echo "Database: interview_db"
echo "Table: trades"
echo "Fields:"
echo "  - id: SERIAL PRIMARY KEY"
echo "  - symbol: TEXT"
echo "  - price: NUMERIC(18,8)"
echo "  - quantity: NUMERIC(18,8)"
echo "  - price_per_unit: NUMERIC(18,8) (computed)"
echo "  - trade_timestamp: TIMESTAMPTZ"
echo "  - suspicious: BOOLEAN"
echo

echo "================================="
echo "generated: $(date)"
EOF

cd /tmp
tar czf /home/$SSH_USER/help.tar.gz help.sh
sudo chown $SSH_USER:$SSH_USER /home/$SSH_USER/help.tar.gz
rm /tmp/help.sh

# Reload systemd and start services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable tech-interview-stand-backend
sudo systemctl enable tech-interview-stand-binance
sudo systemctl start tech-interview-stand-backend
sudo systemctl start tech-interview-stand-binance
sudo systemctl restart nginx

echo "Deployment completed successfully!"
echo "You can check service status with:"
echo "sudo systemctl status tech-interview-stand-backend"
echo "sudo systemctl status tech-interview-stand-binance"
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

# Add Environment=DATABASE_URL=postgresql://interview_service_user:interview_password@localhost:5432/interview_db to systemd service files
sudo sed -i "s/Environment=.*/Environment=DATABASE_URL=postgresql:\/\/interview_service_user:interview_password@localhost:5432\/interview_db/" /etc/systemd/system/tech-interview-stand-backend.service
sudo sed -i "s/Environment=.*/Environment=DATABASE_URL=postgresql:\/\/interview_service_user:interview_password@localhost:5432\/interview_db/" /etc/systemd/system/tech-interview-stand-binance.service 
#!/bin/bash

echo "🔑 Your SSH Credentials"
echo "======================"
echo "Username: $(whoami)"
echo "Password: (the one you used to connect)"
echo

echo "⚠️  Troubleshooting Access"
echo "========================"
echo "For troubleshooting, switch to interview_user:"
echo "   su - interview_user"
echo "   Password: (check deploy.sh output for the generated password)"
echo
echo "This user has sudo rights and is intended for system maintenance."
echo

echo "📚 Available Commands"
echo "==================="
echo "1. View trades in database:"
echo "   sudo -u postgres psql -d interview_db -c \"SELECT * FROM trades ORDER BY trade_timestamp DESC LIMIT 5;\""
echo
echo "2. Check service status:"
echo "   sudo systemctl status tech-interview-stand-backend"
echo "   sudo systemctl status tech-interview-stand-binance"
echo "   sudo systemctl status nginx"
echo
echo "3. View service logs:"
echo "   sudo journalctl -u tech-interview-stand-backend"
echo "   sudo journalctl -u tech-interview-stand-binance"
echo
echo "4. Test API endpoints:"
echo "   curl http://localhost:8000/api/trades"
echo "   curl http://localhost:8000/api/trades?limit=5"
echo

echo "🔧 System Information"
echo "==================="
echo "1. Backend (FastAPI)"
echo "   - Port: 8000"
echo "   - Endpoints:"
echo "     * GET /api/trades - List all trades"
echo "     * GET /api/trades?limit=N - List N latest trades"
echo
echo "2. Binance Service"
echo "   - Fetches trades from Binance API"
echo "   - Transforms data and adds suspicious flag"
echo "   - Saves trades to PostgreSQL"
echo
echo "3. Frontend (Nginx)"
echo "   - Serves static files"
echo "   - Proxies API requests to backend"
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

echo "🔍 Known Issues"
echo "============="
echo "1. Binance Service:"
echo "   - Uses BTCUSD instead of BTCUSDT"
echo "   - Quantity is stored as string instead of Decimal"
echo "   - Suspicious flag is stored as string instead of boolean"
echo
echo "2. Backend:"
echo "   - Returns trades as string instead of JSON"
echo

echo "📝 Important Notes"
echo "================"
echo "- All services run under interview_service_user"
echo "- Database credentials are in /etc/tech-interview-stand/db-url"
echo "- Frontend files are in /var/www/tech-interview-stand"
echo "- Python virtual environment is in /opt/app/interview-service/venv"
echo

echo "================================="
echo "Last updated: $(date)" 
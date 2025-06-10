let previousTrades = new Set();

async function fetchTrades() {
  try {
    console.log('Fetching trades...');
    const res = await fetch('/api/trades?limit=20');
    console.log('Response status:', res.status);
    if (!res.ok) {
      console.error('Error fetching trades:', res.status, res.statusText);
      return;
    }
    const data = await res.json();
    console.log('Received data:', data);
    
    const tbody = document.querySelector('#trades tbody');
    const noTradesDiv = document.querySelector('#no-trades');
    
    if (!data || data.length === 0) {
      tbody.innerHTML = '';
      noTradesDiv.style.display = 'block';
      return;
    }
    
    noTradesDiv.style.display = 'none';
    tbody.innerHTML = '';
    
    const currentTrades = new Set();
    
    // Take only the first 20 trades
    data.slice(0, 20).forEach(t => {
      const tradeKey = `${t.trade_timestamp}-${t.quantity}-${t.price}`;
      currentTrades.add(tradeKey);
      
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${new Date(t.trade_timestamp).toLocaleString('en-US', {timeZone: 'UTC'})}</td>
        <td>${t.quantity}</td>
        <td>${t.price}</td>
      `;
      
      // Add highlight class if this is a new trade
      if (!previousTrades.has(tradeKey)) {
        tr.classList.add('highlight');
      }
      
      tbody.appendChild(tr);
    });
    
    previousTrades = currentTrades;
  } catch (error) {
    console.error('Error in fetchTrades:', error);
  }
}

// Initial fetch
fetchTrades();

// Fetch every 5 seconds
setInterval(fetchTrades, 5000);

const express = require('express');
const axios = require('axios');
const cheerio = require('cheerio');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// Stateless proxy endpoint: accepts credentials, scrapes SRU portal server-side, returns JSON, and discards passwords instantly.
app.post('/api/scrape-attendance', async (req, res) => {
  const { username, password } = req.body;
  
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Username and password required' });
  }

  try {
    // Bypasses browser CORS restrictions by executing the request server-side
    const portalResponse = await axios.post('https://sraap.in/student/dash_board.php', 
      new URLSearchParams({ username, password }), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      }
    );

    const $ = cheerio.load(portalResponse.data);
    const attendanceList = [];

    // Parse attendance table rows from the dashboard DOM
    $('table tr').each((i, row) => {
      const cols = $(row).find('td');
      if (cols.length >= 3) {
        attendanceList.push({
          name: $(cols[0]).text().trim(),
          present: parseInt($(cols[1]).text().trim()) || 0,
          held: parseInt($(cols[2]).text().trim()) || 0,
        });
      }
    });

    res.json({ success: true, data: attendanceList });
  } catch (error) {
    // Fallback response if portal is down or credentials fail
    res.status(500).json({ 
      success: false, 
      message: 'Failed to reach portal or invalid credentials',
      error: error.message 
    });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Student Square Backend running on http://localhost:${PORT}`);
});
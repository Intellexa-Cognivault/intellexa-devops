require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const db = require('./db');

const app = express();
const port = 3000;

app.use(bodyParser.json());

// Get all documents
app.get('/documents', async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM documents ORDER BY id ASC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get document by id
app.get('/documents/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  try {
    const result = await db.query('SELECT * FROM documents WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new document
app.post('/documents', async (req, res) => {
  const { content, docId, userId } = req.body;
  try {
    const result = await db.query(
      'INSERT INTO documents (content, docId, userId) VALUES ($1, $2, $3) RETURNING *',
      [content, docId, userId]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update document by id
app.put('/documents/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  const { content, docId, userId } = req.body;
  try {
    const result = await db.query(
      'UPDATE documents SET content = $1, docId = $2, userId = $3 WHERE id = $4 RETURNING *',
      [content, docId, userId, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete document by id
app.delete('/documents/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  try {
    const result = await db.query('DELETE FROM documents WHERE id = $1 RETURNING *', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found' });
    }
    res.json({ message: 'Document deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(port, () => {
  console.log(`Documents API listening at http://localhost:${port}`);
});

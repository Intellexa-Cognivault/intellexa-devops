require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.POSTGRES_USER,
  host: 'localhost',
  database: process.env.POSTGRES_DB,
  password: process.env.POSTGRES_PASSWORD,
  port: 5432,
});

module.exports = {
  query: (text, params) => pool.query(text, params),
};

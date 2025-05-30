const { Pool } = require('pg');

const pool = new Pool({
  user: 'intellexa',
  host: 'localhost',
  database: 'intellexa',
  password: 'intellexa123',
  port: 5432,
});

module.exports = {
  query: (text, params) => pool.query(text, params),
};

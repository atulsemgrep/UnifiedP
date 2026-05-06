// vulnerable-db.js
const userInput = req.body.id;
const query = `SELECT * FROM users WHERE id = ${userInput}`; // Vulnerable to SQL Injection!
db.query(query, (err, results) => {
    // process results
});

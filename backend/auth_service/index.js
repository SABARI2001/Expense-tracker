const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { createClient } = require('redis');
const { Pool } = require('pg');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const PORT = process.env.PORT || 3000;
const SERVER_ID = process.env.SERVER_ID || 'server-1';

// Redis Client (Shared Session Store)
const redisClient = createClient({
    url: process.env.REDIS_URL || 'redis://redis:6379'
});
redisClient.connect().catch(console.error);

// DB Pool (User Data)
const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgres://user:password@db:5432/myapp'
});

app.get('/', (req, res) => {
    res.send(`Auth Service RUNNING on ${SERVER_ID}`);
});

app.post('/register', async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).send('Missing fields');

    try {
        const hash = await bcrypt.hash(password, 10);
        await pool.query('INSERT INTO users (email, password_hash) VALUES ($1, $2)', [email, hash]);
        res.status(201).send('User created');
    } catch (e) {
        console.error(e);
        res.status(500).send('Error registering user');
    }
});

app.get('/login', (req, res) => {
    res.send(`
        <h1>Login to ${SERVER_ID}</h1>
        <form method="POST" action="/login">
            <input type="email" name="email" placeholder="Email" value="test@example.com" required /><br/>
            <input type="password" name="password" placeholder="Password" value="password123" required /><br/>
            <button type="submit">Login</button>
        </form>
        <hr/>
        <h2>Register</h2>
        <form method="POST" action="/register">
            <input type="email" name="email" placeholder="Email" required /><br/>
            <input type="password" name="password" placeholder="Password" required /><br/>
            <button type="submit">Register</button>
        </form>
    `);
});

app.post('/login', async (req, res) => {
    const { email, password } = req.body;

    try {
        // 1. Check DB for user
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) return res.status(401).send('Invalid credentials');

        const user = result.rows[0];

        // 2. Hash Compare
        const valid = await bcrypt.compare(password, user.password_hash);
        if (!valid) return res.status(401).send('Invalid credentials');

        // 3. Generate Token
        const token = jwt.sign({ id: user.id, email: user.email }, 'SECRET_KEY', { expiresIn: '1h' });

        // 4. Store Valid Session in Redis (HA)
        await redisClient.set(`session:${user.id}`, token, { EX: 3600 });

        res.json({ token, server: SERVER_ID });
    } catch (e) {
        console.error(e);
        res.status(500).send('Internal Server Error');
    }
});

app.post('/verify', async (req, res) => {
    const { token } = req.body;
    try {
        const decoded = jwt.verify(token, 'SECRET_KEY');

        // Check Redis for active session
        const session = await redisClient.get(`session:${decoded.id}`);
        if (!session) return res.status(401).send('Session expired');

        res.json({ valid: true, server: SERVER_ID });
    } catch (e) {
        res.status(401).send('Invalid token');
    }
});

app.listen(PORT, () => {
    console.log(`Auth Service ${SERVER_ID} listening on port ${PORT}`);
});

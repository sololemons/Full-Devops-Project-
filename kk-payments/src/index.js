const express = require('express');
const path = require('path');
const { randomUUID } = require('crypto');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const app = express();
const port = 8067;

app.use(express.json());

const s3Client = new S3Client({ 
    region: process.env.AWS_REGION || 'us-west-1' 
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME;

if (!BUCKET_NAME) {
    console.error("FATAL ERROR: S3_BUCKET_NAME environment variable is missing!");
    process.exit(1); 
}

app.get('/api/health', (req, res) => {
    res.status(200).json({ status: 'healthy', message: 'Kubernetes probes passing' });
});

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

app.post('/api/pay', async (req, res) => {
    const id = randomUUID();
    const { amount = 10 } = req.body;
    
    const receiptData = { 
        id, 
        amount, 
        status: 'payment_successful', 
        timestamp: new Date().toISOString() 
    };
    
    try {
        const command = new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: `receipts/${id}.json`,
            Body: JSON.stringify(receiptData, null, 2),
            ContentType: 'application/json'
        });

        await s3Client.send(command);
        console.log(`[Success] Wrote receipt ${id} to S3 bucket: ${BUCKET_NAME}`);

        res.json({ success: true, id });

    } catch (err) {
        console.error('[Error] S3 Upload failed:', err);
        res.status(500).json({ error: 'Failed to process payment and trigger receipt' });
    }
});

app.listen(port, () => {
    console.log(`KijaniKiosk Mock running at http://localhost:${port}`);
    console.log(`Configured to write to S3 Bucket: ${BUCKET_NAME}`);
});
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 50511;
const BASE_PATH = '/demo';
const PUBLIC_DIR = path.join(__dirname, 'public');
const ENABLE_CROSS_ORIGIN_ISOLATION = process.env.ENABLE_CROSS_ORIGIN_ISOLATION === '1';

const MIME_TYPES = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.wasm': 'application/wasm',
    '.pck': 'application/octet-stream',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
    '.css': 'text/css',
    '.json': 'application/json'
};

const server = http.createServer((req, res) => {
    // Only handle requests under /demo
    if (!req.url.startsWith(BASE_PATH)) {
        res.statusCode = 404;
        res.end('Not Found');
        return;
    }

    // Remove /demo prefix to get the actual file path
    let filePath = req.url.substring(BASE_PATH.length);
    if (!filePath || filePath === '/') {
        filePath = '/index.html';
    }

    // Security: prevent directory traversal
    filePath = path.normalize(filePath).replace(/^(\.\.(\/|\$))/, '');
    const fullPath = path.join(PUBLIC_DIR, filePath);

    // Check if file exists
    fs.stat(fullPath, (err, stats) => {
        if (err || !stats.isFile()) {
            // Try index.html for directories
            const indexPath = path.join(fullPath, 'index.html');
            fs.stat(indexPath, (err2, stats2) => {
                if (err2 || !stats2.isFile()) {
                    res.statusCode = 404;
                    res.end('Not Found');
                    return;
                }
                serveFile(indexPath, res);
            });
            return;
        }
        serveFile(fullPath, res);
    });
});

function serveFile(filePath, res) {
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.setHeader('Content-Type', contentType);

    // Keep default mode compatible-first for older mobile browsers.
    // Enable strict isolation only when explicitly requested.
    if (ENABLE_CROSS_ORIGIN_ISOLATION) {
        res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
        res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    }

    const stream = fs.createReadStream(filePath);
    stream.pipe(res);
    stream.on('error', () => {
        res.statusCode = 500;
        res.end('Server Error');
    });
}

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running at http://localhost:${PORT}${BASE_PATH}/`);
});

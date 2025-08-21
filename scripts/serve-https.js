#!/usr/bin/env node
const https = require('https');
const fs = require('fs');
const path = require('path');
const url = require('url');

const HOST = process.env.HOST || '0.0.0.0';
const PORT = parseInt(process.env.PORT, 10) || 8443;
const CERT_DIR = path.join(__dirname, 'certs');
const WORKSPACE = process.cwd();

const keyPath = path.join(CERT_DIR, 'key.pem');
const certPath = path.join(CERT_DIR, 'cert.pem');

function ensureCertsExist() {
  if (!fs.existsSync(keyPath) || !fs.existsSync(certPath)) {
    console.error('Certificates not found. Run the generate script first: scripts/generate-self-signed.sh');
    process.exit(1);
  }
}

function contentType(file) {
  const ext = path.extname(file).toLowerCase();
  switch (ext) {
    case '.html': return 'text/html; charset=utf-8';
    case '.css': return 'text/css; charset=utf-8';
    case '.js': return 'application/javascript; charset=utf-8';
    case '.json': return 'application/json; charset=utf-8';
    case '.png': return 'image/png';
    case '.jpg':
    case '.jpeg': return 'image/jpeg';
    case '.svg': return 'image/svg+xml';
    case '.ico': return 'image/x-icon';
    case '.txt': return 'text/plain; charset=utf-8';
    default: return 'application/octet-stream';
  }
}

ensureCertsExist();

const options = {
  key: fs.readFileSync(keyPath),
  cert: fs.readFileSync(certPath)
};

const server = https.createServer(options, (req, res) => {
  try {
    const parsed = url.parse(req.url || '/');
    let pathname = decodeURIComponent(parsed.pathname || '/');
    if (pathname.includes('..')) {
      res.statusCode = 400;
      return res.end('Invalid path');
    }
    let filePath = path.join(WORKSPACE, pathname);
    fs.stat(filePath, (err, stats) => {
      if (err) {
        res.statusCode = 404;
        return res.end('Not found');
      }
      if (stats.isDirectory()) {
        filePath = path.join(filePath, 'index.html');
      }
      fs.readFile(filePath, (err, data) => {
        if (err) {
          res.statusCode = 404;
          return res.end('Not found');
        }
        res.setHeader('Content-Type', contentType(filePath));
        res.end(data);
      });
    });
  } catch (e) {
    res.statusCode = 500;
    res.end('Server error');
  }
});

server.listen(PORT, HOST, () => {
  console.log(`HTTPS server running at https://${HOST}:${PORT}/`);
  console.log('Serving files from', WORKSPACE);
  console.log('Press Ctrl+C to stop.');
  // Print simple LAN addresses for convenience when binding to 0.0.0.0
  if (HOST === '0.0.0.0') {
    try {
      const os = require('os');
      const nets = os.networkInterfaces();
      Object.keys(nets).forEach((name) => {
        for (const net of nets[name]) {
          if (net.family === 'IPv4' && !net.internal) {
            console.log(`Accessible at: https://${net.address}:${PORT}/`);
          }
        }
      });
    } catch (e) {
      // ignore
    }
  }
});

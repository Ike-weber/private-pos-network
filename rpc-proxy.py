#!/usr/bin/env python3
"""
rpc-proxy.py — TLS-terminating, API-key-authenticated, rate-limited proxy for Geth RPC.

Usage:
  ./rpc-proxy.py --target http://127.0.0.1:8541 --cert rpc-cert.pem --key rpc-key.pem --port 8441
"""

import argparse
import json
import base64
import time
import re
import ssl
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import Request, urlopen

RATE = 10      # requests per second per IP
BURST = 20

class RateLimiter:
    def __init__(self):
        self.buckets = {}

    def allow(self, ip):
        now = time.time()
        tokens, last = self.buckets.get(ip, (BURST, now))
        tokens = min(BURST, tokens + (now - last) * RATE)
        if tokens >= 1:
            self.buckets[ip] = (tokens - 1, now)
            return True
        self.buckets[ip] = (tokens, now)
        return False

limiter = RateLimiter()

def load_users(path):
    users = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line and ':' in line:
                u, p = line.split(':', 1)
                users[u] = p
    return users

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

    def do_POST(self):
        client = self.client_address[0]
        if not limiter.allow(client):
            self.send_response(429)
            self.end_headers()
            self.wfile.write(b'{"jsonrpc":"2.0","error":{"code":-32000,"message":"rate limit exceeded"}}')
            return

        auth = self.headers.get('Authorization', '')
        if not auth.startswith('Basic '):
            self.send_response(401)
            self.send_header('WWW-Authenticate', 'Basic realm="Geth RPC"')
            self.end_headers()
            return

        try:
            creds = base64.b64decode(auth[6:]).decode()
            user, pwd = creds.split(':', 1)
        except Exception:
            self.send_response(403)
            self.end_headers()
            return

        if users.get(user) != pwd:
            self.send_response(403)
            self.end_headers()
            return

        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)

        req = Request(args.target, data=body, headers={'Content-Type': 'application/json'})
        try:
            resp = urlopen(req, timeout=30)
            data = resp.read()
            code = resp.status
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(json.dumps({"jsonrpc":"2.0","error":{"code":-32603,"message":str(e)}}).encode())
            return

        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(data)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', default='http://127.0.0.1:8541')
    parser.add_argument('--cert', default='rpc-cert.pem')
    parser.add_argument('--key', default='rpc-key.pem')
    parser.add_argument('--port', type=int, default=8441)
    parser.add_argument('--users', default='rpc-users.txt')
    args = parser.parse_args()

    users = load_users(args.users)

    httpd = HTTPServer(('127.0.0.1', args.port), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(args.cert, args.key)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)

    print(f"TLS RPC proxy listening on https://127.0.0.1:{args.port} -> {args.target}")
    httpd.serve_forever()

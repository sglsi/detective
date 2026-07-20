#!/usr/bin/env python3
"""Minimal static server for the Godot Web build with correct MIME types.

Serves the directory given by --directory on --port (default 8081), bound to
0.0.0.0. Critical: .wasm must be served as application/wasm so the browser can
use WebAssembly.instantiateStreaming; Godot's loader otherwise falls back to a
slower ArrayBuffer path. The .pck is fetched as application/octet-stream.
"""
import argparse
import http.server
import socketserver
import os

PORT = 8081


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Disable caching during development so rebuilds show immediately.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def guess_type(self, path):
        ext = os.path.splitext(path)[1].lower()
        return {
            ".wasm": "application/wasm",
            ".js": "text/javascript",
            ".mjs": "text/javascript",
            ".pck": "application/octet-stream",
            ".html": "text/html; charset=utf-8",
            ".png": "image/png",
            ".ico": "image/x-icon",
            ".json": "application/json",
            ".css": "text/css",
        }.get(ext, super().guess_type(path))

    def log_message(self, fmt, *args):
        pass  # quiet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=PORT)
    ap.add_argument("--directory", required=True)
    args = ap.parse_args()

    os.chdir(args.directory)
    with socketserver.TCPServer(("0.0.0.0", args.port), Handler) as httpd:
        print(f"Serving {args.directory} on http://0.0.0.0:{args.port}", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
静态文件服务器 + 后端 API 反向代理。
- /api/* → 转发到 http://localhost:3000
- 其他 → 提供静态文件（web_prototype 目录）
解决沙箱代理不支持 /api/auth/* 路径的问题。
"""
import argparse
import http.server
import socketserver
import os
import urllib.request
import urllib.error

PORT = 8080
BACKEND = "http://localhost:3001"


class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/api/"):
            return self._proxy("GET")
        return super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/"):
            return self._proxy("POST")
        return super().do_POST()

    def do_PUT(self):
        if self.path.startswith("/api/"):
            return self._proxy("PUT")
        return super().do_PUT()

    def do_DELETE(self):
        if self.path.startswith("/api/"):
            return self._proxy("DELETE")
        return super().do_DELETE()

    def do_OPTIONS(self):
        if self.path.startswith("/api/"):
            return self._proxy("OPTIONS")
        return super().do_OPTIONS()

    def _proxy(self, method):
        """将请求转发到后端 localhost:3000"""
        target_url = BACKEND + self.path
        if self.headers.get("Content-Length"):
            body = self.rfile.read(int(self.headers["Content-Length"]))
        else:
            body = None

        req = urllib.request.Request(target_url, data=body, method=method)

        # 透传关键请求头
        for hdr in ["Content-Type", "Authorization", "Accept"]:
            val = self.headers.get(hdr)
            if val:
                req.add_header(hdr, val)

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                # 透传 CORS 和 Content-Type
                for hdr in ["Content-Type", "Access-Control-Allow-Origin",
                            "Access-Control-Allow-Methods", "Access-Control-Allow-Headers",
                            "Access-Control-Allow-Credentials", "Authorization"]:
                    val = resp.headers.get(hdr)
                    if val:
                        self.send_header(hdr, val)
                # 始终加 CORS 头（兜底）
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(f'{{"error":"后端代理失败: {e}"}}'.encode())

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def guess_type(self, path):
        ext = os.path.splitext(path)[1].lower()
        return {
            ".html": "text/html; charset=utf-8",
            ".js": "text/javascript",
            ".mjs": "text/javascript",
            ".css": "text/css",
            ".json": "application/json",
            ".png": "image/png",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".webp": "image/webp",
            ".ico": "image/x-icon",
            ".svg": "image/svg+xml",
            ".wasm": "application/wasm",
        }.get(ext, super().guess_type(path))

    def log_message(self, fmt, *args):
        pass  # quiet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=PORT)
    ap.add_argument("--directory", required=True)
    args = ap.parse_args()

    os.chdir(args.directory)
    # 多线程：/api/* 代理是同步阻塞调用，单线程会拖死静态资源请求（导致整站卡死）。
    with http.server.ThreadingHTTPServer(("0.0.0.0", args.port), ProxyHandler) as httpd:
        print(f"[Proxy Server] Serving {args.directory} on 0.0.0.0:{args.port}", flush=True)
        print(f"[Proxy Server] /api/* → {BACKEND}", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()

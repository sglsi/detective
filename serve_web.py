#!/usr/bin/env python3
"""Static server for the Godot Web build WITH same-origin /api proxy.

Serves the directory given by --directory on --port (default 8081), bound to
0.0.0.0. Critical: .wasm must be served as application/wasm so the browser can
use WebAssembly.instantiateStreaming; Godot's loader otherwise falls back to a
slower ArrayBuffer path. The .pck is fetched as application/octet-stream.

后端反向代理：/api/* → http://localhost:3001
为什么需要它：Godot Web 构建里，浏览器向「绝对地址」http://localhost:3001 发跨域
fetch（尤其是带 JSON body 的 POST）会在运行期失败（沙箱/远程预览下 localhost:3001
不可达，或跨域预检被拦），表现为注册/登录「网络请求失败」。改为同源请求 /api，
由本服务器在服务端转发到后端，彻底消除跨域与可达性问题。
"""
import argparse
import http.server
import socketserver
import os
import urllib.request
import urllib.error

PORT = 8081
BACKEND = "http://localhost:3001"


class Handler(http.server.SimpleHTTPRequestHandler):
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
        target_url = BACKEND + self.path
        length = self.headers.get("Content-Length")
        body = self.rfile.read(int(length)) if length else None

        req = urllib.request.Request(target_url, data=body, method=method)
        for hdr in ["Content-Type", "Authorization", "Accept"]:
            val = self.headers.get(hdr)
            if val:
                req.add_header(hdr, val)

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                for hdr in ["Content-Type", "Access-Control-Allow-Origin",
                            "Access-Control-Allow-Methods", "Access-Control-Allow-Headers",
                            "Access-Control-Allow-Credentials", "Authorization"]:
                    val = resp.headers.get(hdr)
                    if val:
                        self.send_header(hdr, val)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(f'{{"error":"后端代理失败: {e}"}}'.encode())

    def end_headers(self):
        # Disable caching during development so rebuilds show immediately.
        self.send_header("Cache-Control", "no-store")
        # NOTE: 本游戏 GODOT_THREADS_ENABLED=false（单线程 wasm，不需要跨域隔离）。
        # 因此不设置 COOP/COEP，否则 require-corp 会阻止游戏页面向本机后端
        # (localhost:3001) 发起跨域 HTTPRequest（后端仅返回
        # Cross-Origin-Resource-Policy: same-origin，COEP 下会被拦截）。
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
    # 多线程：/api/* 代理是同步阻塞调用，单线程会拖死静态资源请求（导致整站卡死）。
    with http.server.ThreadingHTTPServer(("0.0.0.0", args.port), Handler) as httpd:
        print(f"Serving {args.directory} on http://0.0.0.0:{args.port}  (/api/* → {BACKEND})", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()

"""本地静态服务器：强制禁用浏览器缓存，避免改了 web_build 后刷新看不到新包。

问题背景：
    `python -m http.server` 不发送 Cache-Control / Expires 头，浏览器会用「启发式缓存」
    继续复用旧的 index.html。旧 index.html 里的 mainPack 指向旧版本戳（如
    index.pck?v=20260828-2032），浏览器按 URL 命中缓存，于是整个旧包被复用，
    普通刷新无效，必须硬刷新（Ctrl+Shift+R）——非常容易误判成「导出没生效」。

用法（在 godot_project 目录下执行）：
    python tools/serve_web_nocache.py [端口] [目录]
    python tools/serve_web_nocache.py 8081 web_build

然后用 http://localhost:<端口>/ 访问。所有响应统一附加 no-store，
刷新即可拿到最新包，无需硬刷新。
"""
import http.server
import os
import sys


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Expires", "0")
        self.send_header("Pragma", "no-cache")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8081
    directory = sys.argv[2] if len(sys.argv) > 2 else "web_build"

    if not os.path.isdir(directory):
        print("ERROR: directory not found: %s" % directory)
        print("       run this from the godot_project directory")
        sys.exit(1)

    handler = functools_partial(directory)
    httpd = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
    print("serving %s at http://localhost:%d/  (no-store enabled)" % (os.path.abspath(directory), port))
    print("press Ctrl+C to stop")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")
        httpd.server_close()


def functools_partial(directory: str):
    """Return a handler class bound to the given directory (py3.7+ compatible)."""
    import functools
    return functools.partial(NoCacheHandler, directory=directory)


if __name__ == "__main__":
    main()

# Dev helper: receives script sources POSTed from Studio (HttpService) and saves them under
# tools/dev/pulled/<path>, so Studio-side edits can be brought back into the local mirror.
import http.server, os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pulled")
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        rel = self.path.lstrip("/").split("?")[0]
        dest = os.path.normpath(os.path.join(ROOT, rel))
        if not dest.startswith(ROOT):
            self.send_response(400); self.end_headers(); return
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        data = self.rfile.read(int(self.headers["Content-Length"]))
        open(dest, "wb").write(data)
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    def log_message(self, *a):
        pass
http.server.HTTPServer(("127.0.0.1", 34894), H).serve_forever()

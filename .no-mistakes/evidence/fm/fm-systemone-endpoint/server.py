import http.server, ssl, json, sys
port, log, mode = int(sys.argv[1]), sys.argv[2], sys.argv[3]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0)); body = json.loads(self.rfile.read(n))
        auth = self.headers.get('Authorization', '')
        rec = {"path": self.path, "host": self.headers.get('Host'), "auth_scheme": auth.split(' ')[0] if auth else None,
               "auth_key_matches_LIVE_KEY": auth == "Bearer live-test-key-not-real", "model": body.get("model"),
               "question_type": body["questions"]["rule"]["type"], "criteria": sorted(body["questions"]["rule"]["criteria"]),
               "project": body["state"]["task"]["project"]}
        open(log, 'a').write(json.dumps(rec) + "\n")
        if self.path != "/v1/systemone":
            self.send_response(404); self.end_headers(); self.wfile.write(b'{"error":"not found"}'); return
        resp = {"answers": {"rule": {"type": "choice", "choice": "rule_1", "confidence": 0.93,
                "probabilities": {"rule_1": 0.93, "default": 0.07}}}, "usage": {"input_tokens": 400, "output_tokens": 9}}
        if mode == "with-model": resp["model"] = "server-named-" + body.get("model")
        out = json.dumps(resp).encode()
        self.send_response(200); self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', str(len(out))); self.end_headers(); self.wfile.write(out)
    def log_message(self, *a): pass
s = http.server.HTTPServer(('127.0.0.1', port), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain('cert.pem', 'key.pem')
s.socket = ctx.wrap_socket(s.socket, server_side=True); s.serve_forever()

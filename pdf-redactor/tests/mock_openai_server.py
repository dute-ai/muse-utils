#!/usr/bin/env python3
"""Mock OpenAI-compatible server standing in for mlx_lm.server.
Returns one in-text value (a name the pattern pass keeps) and one
hallucinated value NOT in the text (must be filtered by redact.py)."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class H(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(length)
        payload = {"choices": [{"message": {"role": "assistant",
                    "content": '["John Q Taxpayer", "999-99-9999"]'}}]}
        out = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", 18080), H).serve_forever()

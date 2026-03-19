#!/usr/bin/env python3
"""Mock HackerNews API server for testing. Stdlib only."""
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

STORIES = {str(i): {"id": i, "title": f"Story {i}", "url": f"https://example.com/{i}", "score": i * 10, "by": f"user_{i}"} for i in range(1, 6)}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/v0/topstories.json":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps([1, 2, 3, 4, 5]).encode())
        elif self.path.startswith("/v0/item/") and self.path.endswith(".json"):
            item_id = self.path.split("/")[-1].replace(".json", "")
            if item_id in STORIES:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(STORIES[item_id]).encode())
            else:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # suppress logs

if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", 18200), Handler)
    server.serve_forever()

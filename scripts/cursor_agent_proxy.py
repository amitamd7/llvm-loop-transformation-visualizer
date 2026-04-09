#!/usr/bin/env python3
"""
Local CORS proxy: OpenAI-shaped POST /v1/chat/completions -> Cursor Cloud Agents API.

Cursor's api.cursor.com uses HTTP Basic auth and is not callable directly from a
browser page (CORS). This script runs on localhost so the visualizer can POST
here with your Cursor API key.

Prerequisites:
  - API key from https://cursor.com/settings (Cloud Agents / Developer API)
  - A GitHub repository URL the key is allowed to target

Usage:
  python3 scripts/cursor_agent_proxy.py [--port 8787]

The browser sends:
  POST http://127.0.0.1:8787/v1/chat/completions
  Authorization: Bearer <CURSOR_API_KEY>
  Content-Type: application/json

Body: normal OpenAI chat payload plus:
  "_cursor_repository": "https://github.com/org/repo"
  "_cursor_ref": "main"   (optional)

This creates a Cloud Agent task, polls until it finishes, fetches the task
conversation, and returns the last assistant text in OpenAI response shape.
Each request starts a new agent (slow; intended for occasional insights).
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any

API_BASE = "https://api.cursor.com"
POLL_INTERVAL_SEC = 5.0
MAX_WAIT_SEC = 300.0


def basic_header(api_key: str) -> str:
    raw = f"{api_key}:".encode("utf-8")
    return "Basic " + base64.b64encode(raw).decode("ascii")


def api_request(
    method: str,
    path: str,
    api_key: str,
    body: dict[str, Any] | None = None,
) -> Any:
    url = API_BASE + path
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": basic_header(api_key),
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {err}") from e


def messages_to_prompt(messages: list[dict[str, Any]]) -> str:
    parts: list[str] = []
    for m in messages:
        role = m.get("role", "user")
        content = m.get("content", "")
        if isinstance(content, list):
            content = json.dumps(content)
        parts.append(f"### {role}\n{content}")
    return "\n\n".join(parts)


def run_agent_flow(api_key: str, repository: str, ref: str | None, model: str | None, prompt: str) -> str:
    body: dict[str, Any] = {
        "prompt": {"text": prompt},
        "source": {"repository": repository},
    }
    if ref:
        body["source"]["ref"] = ref
    if model:
        body["model"] = model

    created = api_request("POST", "/v0/agents", api_key, body)
    agent_id = created.get("id")
    if not agent_id:
        raise RuntimeError("No agent id in response: " + json.dumps(created)[:500])

    deadline = time.monotonic() + MAX_WAIT_SEC
    status = ""
    while time.monotonic() < deadline:
        info = api_request("GET", f"/v0/agents/{agent_id}", api_key)
        status = str(info.get("status", "")).upper()
        if status in ("FINISHED", "FAILED", "CANCELLED"):
            break
        time.sleep(POLL_INTERVAL_SEC)

    if status != "FINISHED":
        raise RuntimeError(f"Agent ended with status={status!r} (id={agent_id})")

    conv = api_request("GET", f"/v0/agents/{agent_id}/conversation", api_key)
    msgs = conv.get("messages") or []
    assistant_texts = [
        m.get("text", "")
        for m in msgs
        if str(m.get("type", "")).lower() in ("assistant_message", "assistant")
    ]
    if not assistant_texts:
        return json.dumps(
            {
                "note": "No assistant_message in conversation; raw messages follow.",
                "messages": msgs,
            },
            indent=2,
        )
    return "\n\n".join(assistant_texts)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/v1/chat/completions":
            self.send_error(404, "Only /v1/chat/completions is implemented")
            return

        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            self.send_error(401, "Missing Authorization: Bearer <CURSOR_API_KEY>")
            return
        api_key = auth[7:].strip()
        if not api_key:
            self.send_error(401, "Empty API key")
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return

        repository = payload.pop("_cursor_repository", None)
        ref = payload.pop("_cursor_ref", None) or None
        messages = payload.get("messages")
        if not repository or not isinstance(messages, list):
            self.send_error(
                400,
                "Body must include messages[] and _cursor_repository (https://github.com/...)",
            )
            return

        model = payload.get("model") or None
        prompt = messages_to_prompt(messages)

        try:
            text = run_agent_flow(api_key, repository, ref, model, prompt)
        except Exception as e:
            err_body = json.dumps({"error": {"message": str(e)}}).encode("utf-8")
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self._cors()
            self.send_header("Content-Length", str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)
            return

        out = {
            "choices": [
                {
                    "message": {"role": "assistant", "content": text},
                    "finish_reason": "stop",
                }
            ],
            "model": model or "cursor-cloud-agent",
        }
        body = json.dumps(out).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    ap = argparse.ArgumentParser(description="Cursor Cloud Agents proxy for the LLVM visualizer")
    ap.add_argument("--port", type=int, default=8787, help="Listen port (default 8787)")
    ap.add_argument("--bind", default="127.0.0.1", help="Bind address")
    args = ap.parse_args()
    server = HTTPServer((args.bind, args.port), Handler)
    print(
        f"Cursor agent proxy listening on http://{args.bind}:{args.port}/v1/chat/completions",
        file=sys.stderr,
    )
    print("Press Ctrl+C to stop.", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.", file=sys.stderr)


if __name__ == "__main__":
    main()

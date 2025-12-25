#!/usr/bin/env python3
#
# Extended python -m http.server with optional Basic Auth and HTTPS support
# basic auth, based on https://gist.github.com/fxsjy/5465353
# Further extended https://gist.github.com/mauler/593caee043f5fe4623732b4db5145a82 (with help from ChatGPT) to add support for HTTPS
#
# Example:
#   With Auth:
#     python3 http_server_auth.py --bind 192.168.30.4 --user vcf --password vcf123! \
#       --port 443 --directory /path/to/dir --certfile server.crt --keyfile server.key
#
#   Without Auth:
#     python3 http_server_auth.py --bind 192.168.30.4 --port 443 \
#       --directory /path/to/dir --certfile server.crt --keyfile server.key
#

from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
import base64
import os
import ssl
import argparse


class AuthHTTPRequestHandler(SimpleHTTPRequestHandler):
    """HTTP server with optional Basic Auth."""

    def __init__(self, *args, **kwargs):
        username = kwargs.pop("username", None)
        password = kwargs.pop("password", None)

        # If both username & password provided, enable auth
        if username and password:
            self._auth = base64.b64encode(f"{username}:{password}".encode()).decode()
        else:
            self._auth = None  # no auth required

        super().__init__(*args, **kwargs)

    def do_AUTHHEAD(self):
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Protected"')
        self.send_header("Content-type", "text/html")
        self.end_headers()

    def do_GET(self):
        """Serve GET requests, requiring auth only if configured."""
        if not self._auth:
            # No authentication required
            return SimpleHTTPRequestHandler.do_GET(self)

        auth_header = self.headers.get("Authorization")
        if auth_header is None:
            self.do_AUTHHEAD()
            self.wfile.write(b"No auth header received.")
        elif auth_header == "Basic " + self._auth:
            SimpleHTTPRequestHandler.do_GET(self)
        else:
            self.do_AUTHHEAD()
            self.wfile.write(b"Invalid authentication credentials.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Simple HTTPS file server with optional Basic Auth"
    )
    parser.add_argument("--cgi", action="store_true", help="Run as CGI Server")
    parser.add_argument(
        "--bind", "-b",
        metavar="ADDRESS",
        default="127.0.0.1",
        help="Specify bind address [default: 127.0.0.1]",
    )
    parser.add_argument(
        "--directory", "-d",
        default=os.getcwd(),
        help="Specify alternative directory [default: current directory]",
    )
    parser.add_argument(
        "--port", "-p",
        type=int,
        default=8000,
        help="Specify alternate port [default: 8000]",
    )
    parser.add_argument("--username", "-u", metavar="USERNAME", help="Optional username for basic auth")
    parser.add_argument("--password", "-P", metavar="PASSWORD", help="Optional password for basic auth")
    parser.add_argument("--certfile", metavar="CERTFILE", help="Path to TLS certificate file")
    parser.add_argument("--keyfile", metavar="KEYFILE", help="Path to TLS key file")

    args = parser.parse_args()

    handler_class = partial(
        AuthHTTPRequestHandler,
        username=args.username,
        password=args.password,
        directory=args.directory,
    )

    # Create HTTP Server
    httpd = HTTPServer((args.bind, args.port), handler_class)

    # Enable TLS if certificate and key files are provided
    if args.certfile and args.keyfile:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile=args.certfile, keyfile=args.keyfile)
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
        mode = "🔒 HTTPS"
    else:
        mode = "🌐 HTTP"

    # Display startup message
    if args.username and args.password:
        print(f"{mode} server with Basic Auth running on {args.bind}:{args.port}")
    else:
        print(f"{mode} server (no authentication) running on {args.bind}:{args.port}")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped by user.")
        httpd.server_close()
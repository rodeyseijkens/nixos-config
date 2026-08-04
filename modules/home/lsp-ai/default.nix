{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.lsp-ai;
  proxyScript =
    if cfg.organizationId != ""
    then
      pkgs.writeScriptBin "kilo-api-proxy" ''
        #!${pkgs.python3}/bin/python3
        import http.server
        import urllib.request
        import urllib.error

        PORT = 11435
        UPSTREAM = "https://api.kilo.ai"
        ORG_HEADER = "X-KiloCode-OrganizationId"
        ORG_ID = "${cfg.organizationId}"

        class ProxyHandler(http.server.BaseHTTPRequestHandler):
            def do_request(self, method):
                content_length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(content_length) if content_length else None

                url = UPSTREAM + self.path
                headers = {}
                for key, value in self.headers.items():
                    if key.lower() not in ('host', 'content-length', 'connection'):
                        headers[key] = value

                if ORG_ID:
                    headers[ORG_HEADER] = ORG_ID

                req = urllib.request.Request(url, data=body, headers=headers, method=method)
                try:
                    with urllib.request.urlopen(req) as resp:
                        self.send_response(resp.status)
                        for key, value in resp.getheaders():
                            if key.lower() not in ('transfer-encoding', 'connection'):
                                self.send_header(key, value)
                        self.end_headers()
                        self.wfile.write(resp.read())
                except urllib.error.HTTPError as e:
                    self.send_response(e.code)
                    for key, value in e.headers.items():
                        if key.lower() not in ('transfer-encoding', 'connection'):
                            self.send_header(key, value)
                    self.end_headers()
                    self.wfile.write(e.read())

            def do_POST(self):
                self.do_request("POST")

            def do_GET(self):
                self.do_request("GET")

            def do_PUT(self):
                self.do_request("PUT")

            def do_DELETE(self):
                self.do_request("DELETE")

            def log_message(self, format, *args):
                pass

        if __name__ == "__main__":
            server = http.server.HTTPServer(("127.0.0.1", PORT), ProxyHandler)
            server.serve_forever()
      ''
    else null;
  proxyEndpoint =
    if cfg.organizationId != ""
    then "http://localhost:11435/api/gateway/v1/chat/completions"
    else cfg.endpoint;
in {
  options.modules.lsp-ai = {
    enable = mkEnableOption "lsp-ai (AI language server with Kilo Gateway)";
    model = mkOption {
      type = types.str;
      default = "codestral-latest";
      description = "Kilo Gateway model ID";
    };
    endpoint = mkOption {
      type = types.str;
      default = "https://api.kilo.ai/api/gateway/v1/chat/completions";
      description = "Kilo Gateway chat completions endpoint";
    };
    apiKeyEnvVar = mkOption {
      type = types.str;
      default = "KILOCODE_API_KEY";
      description = "Environment variable name for the Kilo API key";
    };
    maxContext = mkOption {
      type = types.int;
      default = 4096;
      description = "Maximum context tokens for completion";
    };
    maxTokens = mkOption {
      type = types.int;
      default = 128;
      description = "Maximum completion tokens";
    };
    organizationId = mkOption {
      type = types.str;
      default = "";
      description = "Kilo organization ID for X-KiloCode-OrganizationId header";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.lsp-ai] ++ lib.optional (cfg.organizationId != "") proxyScript;

    home.file.".local/bin/lsp-ai-kilo" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        SECRET_FILE="/run/secrets/kilo-api-key"
        if [[ -f "$SECRET_FILE" ]]; then
          export ${cfg.apiKeyEnvVar}="$(cat "$SECRET_FILE")"
        else
          echo "Warning: $SECRET_FILE not found" >&2
        fi
        exec lsp-ai "$@"
      '';
    };

    systemd.user.services.kilo-api-proxy = mkIf (cfg.organizationId != "") {
      Unit = {
        Description = "Kilo API Proxy (adds organization header)";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${proxyScript}/bin/kilo-api-proxy";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    xdg.configFile."lsp-ai/config.json".text = builtins.toJSON {
      memory = {file_store = {};};
      models = {
        kilo = {
          type = "open_ai";
          chat_endpoint = proxyEndpoint;
          model = cfg.model;
          auth_token_env_var_name = cfg.apiKeyEnvVar;
        };
      };
      completion = {
        model = "kilo";
        parameters = {
          max_context = cfg.maxContext;
          max_tokens = cfg.maxTokens;
        };
      };
    };
  };
}

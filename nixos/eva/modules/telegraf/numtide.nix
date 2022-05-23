{
  config,
  lib,
  pkgs,
  ...
}: let
in {
  services.telegraf.extraConfig.inputs = {
    x509_cert = [
      {
        sources = [
          "https://matrix.numtide.com:443"
          "https://upterm.numtide.com:443"
          "https://mumble.numtide.com:443"
        ];
        tags.host = "matrix1";
        tags.org = "numtide";
      }
    ];
    net_response =
      map
      (host: {
        protocol = "tcp";
        address = "${host}.numtide.com:22";
        send = "SSH-2.0-Telegraf";
        expect = "SSH-2.0";
        tags.host = host;
        tags.org = "numtide";
        timeout = "10s";
      }) [
        "matrix1"
      ];
    http_response = [
      {
        urls = [
          "https://upterm.numtide.com/"
        ];
        response_string_match = "Usage";
        tags.host = "matrix1";
        tags.org = "numtide";
      }
      {
        urls = [
          "https://matrix.numtide.com/_matrix/static/"
        ];
        response_string_match = "Synapse";
        tags.host = "matrix1";
        tags.org = "numtide";
      }
    ];
  };
}

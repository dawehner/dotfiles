{ pkgs
, lib
, inputs
, ...
}:
with lib; let
  myemacs = pkgs.emacs;
  editorScript =
    { name ? "emacseditor"
    , extraArgs ? [ ]
    ,
    }:
    pkgs.writeScriptBin name ''
      #!${pkgs.runtimeShell}
      export TERM=xterm-direct
      # breaks clipetty in combination with tmux + mosh? https://github.com/spudlyo/clipetty/pull/22
      unset SSH_TTY TMUX
      exec -a emacs ${myemacs}/bin/emacsclient \
        --create-frame \
        --alternate-editor ${myemacs}/bin/emacs \
        -nw \
        ${toString extraArgs} "$@"
    '';

  daemonScript = pkgs.writeScript "emacs-daemon" ''
    #!${pkgs.zsh}/bin/zsh -l
    export PATH=$PATH:${lib.makeBinPath [pkgs.git pkgs.sqlite pkgs.unzip]}
    if [ ! -d $HOME/.emacs.d/.git ]; then
      mkdir -p $HOME/.emacs.d
      git -C $HOME/.emacs.d init
    fi
    git -C $HOME/.emacs.d remote add origin https://github.com/doomemacs/doomemacs.git || \
      git -C $HOME/.emacs.d remote set-url origin https://github.com/doomemacs/doomemacs.git
    # do not downgrade...
    if ! git merge-base --is-ancestor "${inputs.doom-emacs.rev}" HEAD; then
      git -C $HOME/.emacs.d fetch https://github.com/doomemacs/doomemacs.git || true
      git -C $HOME/.emacs.d checkout ${inputs.doom-emacs.rev} || true
      YES=1 FORCE=1 nice -n19 $HOME/.emacs.d/bin/doom sync -u || true
    else
      nice -n19 $HOME/.emacs.d/bin/doom sync || true
    fi
    # This files tends to accumulate a lot of project that it is trying to load at startup
    rm "$HOME/.emacs.d/.local/cache/lsp-session"
    exec ${myemacs}/bin/emacs --daemon
  '';

  # list taken from here: (message "%s" tree-sitter-major-mode-language-alist)
  # commented out are not yet packaged in nix
  langs = [
    # "agda"
    "bash"
    "c"
    "c-sharp"
    "cpp"
    "css"
    "elm"
    #"fluent"
    "go"
    "hcl"
    "html"
    "janet-simple"
    "java"
    "javascript"
    "jsdoc"
    "json"
    "julia"
    "ocaml"
    "pgn"
    "php"
    "python"
    "ruby"
    "rust"
    "scala"
    # "swift"
    "typescript"
  ];
  grammars = lib.getAttrs (map (lang: "tree-sitter-${lang}") langs) pkgs.tree-sitter.builtGrammars;
in
{
  home.file.".tree-sitter".source = pkgs.runCommand "grammars" { } ''
    mkdir -p $out/bin
    ${
      lib.concatStringsSep "\n"
      (lib.mapAttrsToList (name: src: "name=${name}; ln -s ${src}/parser $out/bin/\${name#tree-sitter-}.so") grammars)
    };
  '';

  home.packages = with pkgs; [
    myemacs
    ripgrep

    (editorScript { })
    gopls
    golangci-lint
    (pkgs.runCommand "gotools-${gotools.version}" { } ''
      mkdir -p $out/bin
      # skip tools colliding with binutils
      for p in ${gotools}/bin/*; do
        name=$(basename $p)
        if [[ -x "${binutils-unwrapped}/bin/$name" ]]; then
          continue
        fi
        ln -s $p $out/bin/
      done
    '')
    gotests
    reftools
    gomodifytags
    gopkgs
    impl
    godef
    gogetdoc
  ];

  systemd = lib.mkIf (!pkgs.stdenv.isDarwin) {
    user.services.emacs-daemon = {
      Install.WantedBy = [ "default.target" ];
      Service = {
        Type = "forking";
        TimeoutStartSec = "10min";
        Restart = "always";
        ExecStart = toString daemonScript;
      };
    };
  };
}

{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    neovim
    ouch
    psmisc
    sipcalc
    iperf
    openssl
    binutils
    file
    wget
    htop
    silver-searcher
    lsof
    tcpdump
    tmux
    rsync
    git
    tig
    python3
    strace
    bandwhich
    iotop
    man-pages
    dnsutils
    netcat
    mtr
    whois
    usbutils
    pciutils
  ];
}

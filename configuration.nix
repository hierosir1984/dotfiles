{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = true;
    inherit user;
    # Adopt the existing Apple Silicon Homebrew installation instead of
    # stopping activation when /opt/homebrew is already present.
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    # This is an existing workstation: do not remove undeclared formulae or
    # casks during activation. We can audit and declare them deliberately later.
    onActivation.cleanup = "none";
    # Update Homebrew metadata whenever this configuration is rebuilt. This is
    # intentionally distinct from unattended `brew upgrade` of every package.
    onActivation.autoUpdate = true;
    brews = [
      "herdr"
    ];
    casks = [
      "wezterm"
      "claude-code"
    ];
  };
}

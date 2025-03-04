{
  config,
  pkgs,
  lib,
  ...
}:
let

  cfg = config.services.salt.master;

  fullConfig = lib.recursiveUpdate {
    # Provide defaults for some directories to allow an immutable config dir

    # Default is equivalent to /etc/salt/master.d/*.conf
    default_include = "/var/lib/salt/master.d/*.conf";
    # Default is in /etc/salt/pki/master
    pki_dir = "/var/lib/salt/pki/master";
  } cfg.configuration;

in

{
  options = {
    services.salt.master = {
      enable = lib.mkEnableOption "Salt configuration management system master service";
      configuration = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Salt master configuration as Nix attribute set.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      # Set this up in /etc/salt/master so `salt`, `salt-key`, etc. work.
      # The alternatives are
      # - passing --config-dir to all salt commands, not just the master unit,
      # - setting a global environment variable,
      etc."salt/master".source = pkgs.writeText "master" (builtins.toJSON fullConfig);
      systemPackages = with pkgs; [ salt ];
    };
    systemd.services.salt-master = {
      description = "Salt Master";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = with pkgs; [
        util-linux # for dmesg
      ];
      serviceConfig = {
        ExecStart = "${pkgs.salt}/bin/salt-master";
        LimitNOFILE = 16384;
        Type = "notify";
        NotifyAccess = "all";
      };
      restartTriggers = [
        config.environment.etc."salt/master".source
      ];
    };
  };

  meta.maintainers = with lib.maintainers; [ Flakebi ];
}

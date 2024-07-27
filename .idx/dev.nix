{ pkgs, ... }: {
  channel = "unstable";
  
  packages = [
    pkgs.gleam
    pkgs.erlang_26
  ];

  idx = {
    extensions = [
      "Catppuccin.catppuccin-vsc"
      "gleam.gleam"
      "tamasfe.even-better-toml"
      "rangav.vscode-thunder-client"
    ];
  };
}
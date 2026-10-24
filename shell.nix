{
  pkgs ? import <nixpkgs> { },
}:

let
  # Build Azure CLI with the azure-devops extension included
  azure-cli-with-devops = pkgs.azure-cli.withExtensions [
    pkgs.azure-cli.extensions.azure-devops
  ];
in
pkgs.mkShell {
  packages = [
    pkgs.gh
    pkgs.glab
    azure-cli-with-devops
  ];
}

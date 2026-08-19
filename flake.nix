{
description = "Blake's NixOS configuratioin";

inputs = {
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
home-manager = {
url = "github:nix-community/home-manager";
inputs.nixpkgs.follows = "nixpkgs";
};
};
outputs = { self, nixpkgs, home-manager, ... }: {
nixosConfigurations.t490 = nixpkgs.lib.nixosSystem {
system = "x86_64-linux";

modules = [
./hosts/t490
home-manager.nixosModules.home-manager
];
};
};
}


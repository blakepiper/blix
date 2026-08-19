{
description = "Blake's NixOS configuratioin";

inputs = {
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
};
outputs = { self, nixpkgs, ... }: {
nixosConfigurations.t490 = nixpkgs.lib.nixosSystem {
system = "x86_64-linux";

modules = [
./hosts/t490
];
};
};
}


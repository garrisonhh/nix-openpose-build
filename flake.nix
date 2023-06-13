{
  inputs = {
    nixpkgs.url = github:NixOs/nixpkgs/nixos-23.05;
    atlas.url = github:garrisonhh/nix-atlas-build;
  };

  outputs = { self, nixpkgs, atlas }:
    let
      # project config
      system = "x86_64-linux";

      inherit (pkgs) mkShell;
      inherit (pkgs.stdenv) mkDerivation;
      pkgs = nixpkgs.legacyPackages.${system};
      atlasPkgs = atlas.packages.${system};

      # package management
      openposePkgs = cripple: with pkgs; [
        git
        glog
        protobuf
        caffe
        cudaPackages.cudatoolkit
        cudaPackages.cudnn_8_5_0
        cmake
        opencv
        boost
        hdf5-cpp
        (if (cripple) then atlasPkgs.crippled else atlasPkgs.release)

        # TODO REMOVE
        unixtools.whereis
      ];

      devPkgs = with pkgs.python311Packages; [
        python
        numpy
        opencv4
      ];

      # shell
      devShell = mkShell {
        packages = (openposePkgs true) ++ devPkgs;
      };

      # openpose
      mkOpenpose = cripple: mkDerivation {
        name = "openpose";
        src = builtins.fetchGit {
          name = "openpose";
          url = "https://github.com/CMU-Perceptual-Computing-Lab/openpose.git";
          ref = "master";
          submodules = true;
        };

        patchPhase = ''
          >&2 pwd
          # this is a hack to prevent the cudnn version check from failing
          sed -i 's/???/8.5.0/g' './cmake/Cuda.cmake'
          echo '==============================================================='
          cat './cmake/Cuda.cmake'
          echo '==============================================================='
        '';

        buildInputs = openposePkgs cripple;
        buildPhase = ''
          BUILD="$out/build"

          mkdir -p "$BUILD"
          cmake -S .. -B "$BUILD"
          cd "$BUILD"
          make
        '';
      };

      packages = {
        default = mkOpenpose false;
        release = mkOpenpose false;
        crippled = mkOpenpose true;
      };
    in
      {
        devShells.${system}.default = devShell;
        packages.${system} = packages;
      };
}

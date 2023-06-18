{
  inputs = {
    nixpkgs.url = github:NixOs/nixpkgs/nixos-22.11;
    atlas.url = github:garrisonhh/nix-atlas-build;
    caffe.url = github:garrisonhh/nix-caffe-build;
  };

  outputs = { self, nixpkgs, atlas, caffe }:
    let
      # project config
      name = "openpose";
      system = "x86_64-linux";

      inherit (pkgs) mkShell;
      inherit (pkgs.stdenv) mkDerivation;
      pkgs = nixpkgs.legacyPackages.${system};
      pyPkgs = pkgs.python27Packages;
      atlasPkgs = atlas.packages.${system};
      caffePkgs = caffe.packages.${system};

      # openpose
      mkOpenpose = cripple:
        let
          toggleCrippled = p: if (cripple) then p.crippled else p.release;

          caffe = toggleCrippled caffePkgs;
          atlas = toggleCrippled atlasPkgs;

          caffeDir = caffe.outPath;

          buildInputs =
            [ caffe atlas ] ++
            (with pkgs; [
              git
              glog
              protobuf3_8
              cudaPackages.cudatoolkit
              cudaPackages.cudnn_8_5_0
              opencv
              cmake
              boost
              hdf5-cpp
            ]);
        in mkDerivation {
          inherit name buildInputs;
          src = builtins.fetchGit {
            inherit name;
            url = "https://github.com/garrisonhh/openpose.git";
            ref = "master";
          };

          configurePhase = ''
            mkdir build/
            cmake -Bbuild/ \
                -DBUILD_CAFFE=OFF \
                -DCaffe_INCLUDE_DIRS=${caffeDir}/include/caffe \
                -DCaffe_LIBS=${caffeDir}/lib/libcaffe.so
          '';

          buildPhase = ''
            cd build/
            make -j`nproc` openpose
            cd -
          '';

          installPhase = ''
            >&2 ls

            mkdir -p $out/
            cp -r ./build/* $out/
          '';
        };

      packages = {
        default = mkOpenpose false;
        release = mkOpenpose false;
        crippled = mkOpenpose true;
      };
    in {
      packages.${system} = packages;
    };
}

{
  description = "origiff";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils/main";

    freeze-font-src = {
      url = "github:stephaneyfx/freeze-font";
      flake = false;
    };

    source-sans = {
      url = "github:adobe-fonts/source-sans/3.052R";
      flake = false;
    };

    source-code = {
      url = "github:adobe-fonts/source-code-pro?ref=2.042R-u/1.062R-i/1.026R-vf";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, freeze-font-src, source-sans, source-code }:
  let
    packagesFor = pkgs:
      let
        packageDef = builtins.fromTOML (builtins.readFile "${freeze-font-src}/freeze-font-cli/Cargo.toml");
        freeze-font = pkgs.rustPlatform.buildRustPackage {
          pname = packageDef.package.name;
          version = packageDef.package.version;
          cargoLock = {
            lockFile = "${freeze-font-src}/Cargo.lock";
            allowBuiltinFetchGit = true;
          };
          src = freeze-font-src;
          buildAndTestSubdir = "freeze-font-cli";
        };
        version = "0.2";
        makeKebab = strings:
          pkgs.lib.concatMapStringsSep "-" pkgs.lib.toLower (pkgs.lib.concatMap (pkgs.lib.splitString " ") strings);
        runFreezeFont = { originPath, originName, family, subfamily, features }:
          let
            postscriptName = pkgs.lib.concatMapStrings (pkgs.lib.replaceString " " "") [family subfamily];
            kebabName = makeKebab [family subfamily];
          in ''
            ${freeze-font}/bin/freeze-font --path '${originPath}' freeze \
              --exclude-platform macintosh --clean-names \
              ${pkgs.lib.concatMapStringsSep " " (f: "--feature ${f}") features} \
              --copyright '(c) 2026 Stephane Raux, 2023 Adobe' \
              --family '${family}' --subfamily '${subfamily}' --uid ${kebabName}-${version} \
              --full-name '${family} ${subfamily}' --version ${version} \
              --postscript-name ${postscriptName} \
              --description '${originName} with some opentype features frozen' \
              --out $out/share/fonts/opentype/${kebabName}.otf
          '';
        weights = [
          "ExtraLight"
          "Light"
          "Normal"
          "Medium"
          "Semibold"
          "Bold"
          "Black"
        ];
        slants = ["Regular" "Italic"];
        makeInstall = { dir, originName, family, features }: slant: weight:
          let
            filenameSlant = if slant == "Italic" then "It" else slant;
            filenameSuffix =
              if weight == "Normal" then filenameSlant
              else if slant == "Regular" then weight
              else "${weight}${filenameSlant}";
            baseFilename = pkgs.lib.replaceString " " "" originName;
            originPath = "${dir}/${baseFilename}-${filenameSuffix}.otf";
          in runFreezeFont {
            inherit family originPath;
            originName = "${originName} ${slant}";
            subfamily = "${slant} ${weight}";
            features = features slant;
          };
        install = args: pkgs.lib.crossLists (makeInstall args) [slants weights];
        installSans = install {
          dir = "${source-sans}/OTF";
          originName = "Source Sans 3";
          family = "Origiff";
          features = slant: if slant == "Regular" then ["cv01" "cv03"] else ["cv01" "cv02"];
        };
        installCode = install {
          dir = "${source-code}/OTF";
          originName = "Source Code Pro";
          family = "Origiff Code";
          features = slant: if slant == "Regular" then ["cv02"] else ["cv01"];
        };
        installAll = pkgs.lib.concatMapStringsSep "\n" toString (installSans ++ installCode);
        origiff = pkgs.stdenv.mkDerivation {
          inherit version;
          pname = "origiff";
          src = self;
          installPhase = ''
            mkdir -p $out/share/fonts/opentype
            ${installAll}
          '';
          meta = {
            description = "Origiff fonts";
            homepage = "https://github.com/stephaneyfx/origiff";
            license = pkgs.lib.licenses.ofl;
            platforms = pkgs.lib.platforms.all;
          };
        };
      in {
        inherit origiff;
        default = origiff;
      };
  in {
    overlays.default = final: prev: packagesFor final;
  } // flake-utils.lib.eachDefaultSystem (system: {
    packages = packagesFor nixpkgs.legacyPackages.${system};
  });
}

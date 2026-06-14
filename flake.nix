{
  description = "Typst environment.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    self.submodules = true;
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        lib = pkgs.lib;

        typstWithPkgs = pkgs.typst.withPackages (
          ps: with ps; [
            # typst pkgs here

          ]
        );

        fonts = with pkgs; [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          source-han-sans
          source-han-mono
          source-han-serif
          dejavu_fonts
          liberation_ttf
          libertinus
        ];

        fontPaths = pkgs.lib.strings.concatStringsSep ":" fonts;

        runtimeInputs = [
          typstWithPkgs
          pkgs.coreutils
          pkgs.zellij
        ];

        sourceRoot = ./.;
        sourceRootString = toString sourceRoot;
        typFiles =
          sourceRoot
          |> lib.filesystem.listFilesRecursive
          |> (lib.filter (path: lib.hasSuffix ".typ" (toString path)))
          |> (builtins.map (path: lib.removePrefix "${sourceRootString}/" (toString path)))
          |> (lib.sort lib.lessThan);

        env = ''
          unset SOURCE_DATE_EPOCH
          export PATH=${lib.makeBinPath runtimeInputs}:$PATH
          export TYPST_FONT_PATHS=${lib.escapeShellArg fontPaths}
        '';

        build =
          typFiles
          |> builtins.map (
            typFile:
            let
              pdfFile = lib.escapeShellArg "${lib.removeSuffix ".typ" typFile}.pdf";
            in
            ''
              pdfFile="$outDir"/${pdfFile}
              mkdir -p "$(dirname "$pdfFile")"
              typst compile ${lib.escapeShellArg "./${typFile}"} "$pdfFile"
            ''
          )
          |> builtins.concatStringsSep "\n"
          |> (
            compile:
            pkgs.writeShellScript "diary-build" ''
              ${env}

              outDir="''${1:-result}"
              rm -rf "$outDir"
              mkdir -p "$outDir"

              ${compile}
            ''
          );

        watch =
          let
            kdlString = builtins.toJSON;
            watchLayout =
              typFiles
              |> lib.map (
                typFile:
                let
                  pdfFile = "result/${lib.removeSuffix ".typ" typFile}.pdf";
                in
                ''
                  tab name=${kdlString typFile} {
                    pane command="typst" {
                      args "watch" ${kdlString "./${typFile}"} ${kdlString pdfFile}
                    }
                  }
                ''
              )
              |> (
                tabs:
                pkgs.writeText "watch.kdl" ''
                  layout {
                    default_tab_template {
                      pane size=1 borderless=true {
                        plugin location="zellij:tab-bar"
                      }
                      children
                      pane size=2 borderless=true {
                        plugin location="zellij:status-bar"
                      }
                    }
                    ${lib.concatStringsSep "\n" tabs}
                  }
                ''
              );
            prepareOutputDirs =
              typFiles
              |> lib.map (
                typFile:
                let
                  pdfFile = "result/${lib.removeSuffix ".typ" typFile}.pdf";
                in
                ''mkdir -p "$(dirname ${lib.escapeShellArg pdfFile})"''
              )
              |> builtins.concatStringsSep "\n";
          in
          ''
            ${env}

            if [[ "''${1:-}" == "--dump-layout" ]]; then
              cat ${watchLayout}
              exit 0
            fi

            if ((${toString (builtins.length typFiles)} == 0)); then
              echo "No .typ files found." >&2
              exit 1
            fi

            ${prepareOutputDirs}
            exec zellij --layout ${watchLayout}
          ''
          |> pkgs.writeShellScript "diary-watch";

        tools = [
          typstWithPkgs
          pkgs.git-crypt
          pkgs.gnupg
          pkgs.zellij
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = tools;
          env.TYPST_FONT_PATHS = fontPaths;
          shellHook = ''
            unset SOURCE_DATE_EPOCH
          '';
        };

        apps =
          {
            default = build;
            inherit build watch;
          }
          |> builtins.mapAttrs (
            _: v: {
              type = "app";
              program = "${v}";
            }
          );
      }
    );
}

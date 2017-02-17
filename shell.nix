{ nixpkgs ? import <nixpkgs> {}, compiler ? "default" }:

let

  inherit (nixpkgs) pkgs;

  f = { mkDerivation, base, deepseq, html-entities, lambdabot-core
      , lambdabot-haskell-plugins, lambdabot-irc-plugins
      , lambdabot-misc-plugins, lambdabot-novelty-plugins
      , lambdabot-reference-plugins, lambdabot-social-plugins
      , lambdabot-trusted, lens, parsec, silently, slack-api, stdenv
      , text, transformers, utf8-string
      }:
      mkDerivation {
        pname = "slack-lambdabot";
        version = "0.1.0.0";
        src = ./.;
        isLibrary = false;
        isExecutable = true;
        executableHaskellDepends = [
          base deepseq html-entities lambdabot-core lambdabot-haskell-plugins
          lambdabot-irc-plugins lambdabot-misc-plugins
          lambdabot-novelty-plugins lambdabot-reference-plugins
          lambdabot-social-plugins lambdabot-trusted lens parsec silently
          slack-api text transformers utf8-string
        ];
        description = "Lambdabot for Slack";
        license = stdenv.lib.licenses.unfree;
      };

  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  drv = haskellPackages.callPackage f {};

in

  if pkgs.lib.inNixShell then drv.env else drv

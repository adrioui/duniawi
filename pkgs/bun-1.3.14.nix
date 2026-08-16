# Bun pinned to 1.3.14 via store zip. Upstream re-published the release
# zip, so its hash uses the verified SRI value. Remove when nixpkgs updates.
{ fetchurl, bun }:

bun.overrideAttrs (_old: {
  version = "1.3.14";
  src = fetchurl {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.14/bun-darwin-aarch64.zip";
    sha256 = "sha256-2LliIYKK1vl6x6wKt+lYcjQa92MAHogD6CZ2UsJlJiA=";
  };
})

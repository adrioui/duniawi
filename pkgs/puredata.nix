# Pure Data currently fails to build on macOS with nixpkgs-unstable's SDK 14.4
# because upstream's configure hard-codes -mmacosx-version-min=10.6 while the
# SDK marks strnlen as 10.7+ and -Werror turns that into a build failure.
# Downgrade that availability error to a warning until nixpkgs fixes the package.
{ puredata }:

puredata.overrideAttrs (old: {
  NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -Wno-error=unguarded-availability";
})

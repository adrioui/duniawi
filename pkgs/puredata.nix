{ puredata }:

puredata.overrideAttrs (old: {
  NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -Wno-error=unguarded-availability";
})

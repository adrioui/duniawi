# Proxychains-ng Setup for macOS + nix-darwin

## Overview

This configuration sets up **proxychains-ng** as a torsocks alternative on macOS using nix-darwin and home-manager.

## What is proxychains-ng?

Proxychains-ng is a preloader that hooks network-related libc functions in dynamically linked programs and redirects connections through SOCKS4a/5 or HTTP proxies. It's a more modern and actively maintained alternative to torsocks.

## macOS-Specific Considerations

### System Integrity Protection (SIP)

**Important:** macOS 10.11 (El Capitan) and later include System Integrity Protection (SIP), which can interfere with proxychains-ng's LD_PRELOAD mechanism.

**Symptoms:**
- proxychains4 appears to run but doesn't actually proxy connections
- No error messages, but traffic goes directly

**Solutions:**

1. **For system binaries** (like `/bin/ls`, `/usr/bin/curl`):
   - Copy the binary to your home directory and run from there
   - Example: `cp /usr/bin/curl ~/curl && proxychains4 ~/curl https://example.com`

2. **For SIP-protected apps**:
   - Use binaries from nixpkgs instead of system binaries
   - The nix-installed `curl`, `wget`, etc. work fine with proxychains

3. **Disabling SIP** (NOT RECOMMENDED):
   - Boot into Recovery Mode (Cmd+R)
   - Run: `csrutil disable`
   - This reduces system security

### Apple Silicon (M1/M2/M3) Support

Proxychains-ng works on Apple Silicon Macs. The nixpkgs version is built as a universal binary supporting both x86_64 and arm64.

## Configuration

### Default Setup

The configuration includes:
- `strict_chain` mode (all proxies must be online)
- `proxy_dns` enabled (prevents DNS leaks)
- Default Tor proxy at `127.0.0.1:9050` (SOCKS5)

### Customizing Proxies

Edit `~/.config/proxychains/proxychains.conf`:

```ini
[ProxyList]
# Tor (default)
socks5  127.0.0.1 9050

# Custom SOCKS5 proxy
socks5  192.168.1.100 1080 username passphrase

# HTTP proxy
http    10.0.0.1 8080
```

### Chain Modes

1. **strict_chain** (default): All proxies must work
2. **dynamic_chain**: Skip dead proxies
3. **random_chain**: Random proxy selection
4. **round_robin_chain**: Rotate through proxies

## Usage

### Basic Usage

```bash
# Run any command through the proxy
proxychains4 curl https://check.torproject.org

# Using the alias
pc curl https://api.ipify.org

# Test if Tor is working
pc-test
```

### With Tor

1. Install and start Tor:
   ```bash
   # Via nix (add to system packages)
   pkgs.tor

   # Or via Homebrew
   brew install tor
   brew services start tor
   ```

2. Verify Tor is running on port 9050:
   ```bash
   lsof -i :9050
   ```

3. Use proxychains:
   ```bash
   proxychains4 curl https://check.torproject.org/api/ip
   ```

### Common Commands

```bash
# Git through proxy
proxychains4 git clone https://github.com/user/repo.git

# SSH through proxy (requires netcat)
proxychains4 ssh user@host

# Browser (may have issues with complex apps)
proxychains4 /Applications/Firefox.app/Contents/MacOS/firefox
```

## Troubleshooting

### "DLL init" message doesn't appear

If you don't see `[proxychains] DLL init: proxychains-ng 4.x`, SIP may be blocking the preload.

**Fix:** Use nix-installed binaries instead of system binaries.

### DNS leaks

Make sure `proxy_dns` is enabled in the config. This routes DNS requests through the proxy.

### Connection timeouts

Adjust timeout values in the config:
```ini
tcp_read_time_out 30000
tcp_connect_time_out 15000
```

### Some apps don't work

Proxychains-ng doesn't work with:
- Statically linked binaries
- Apps that use dlopen() extensively (some Python/Node apps)
- System binaries protected by SIP

**Workarounds:**
- Use dynamically linked versions from nixpkgs
- For Python: use `requests` with SOCKS support instead
- For Node: use `socks-proxy-agent`

## Security Notes

1. **Always verify** proxychains is working before sensitive operations:
   ```bash
   proxychains4 curl https://check.torproject.org/api/ip
   ```

2. **DNS leaks**: With `proxy_dns` enabled, DNS goes through the proxy. Without it, DNS may leak.

3. **UDP not supported**: proxychains-ng only supports TCP.

4. **ICMP not supported**: ping won't work through proxychains.

## Comparison with torsocks

| Feature | proxychains-ng | torsocks |
|---------|----------------|----------|
| macOS support | Better | Problematic with SIP |
| Proxy types | SOCKS4/5, HTTP | SOCKS5 only |
| Proxy chaining | Yes | No |
| Active development | Yes | Limited |
| DNS proxying | Yes | Yes |

## References

- [proxychains-ng GitHub](https://github.com/rofl0r/proxychains-ng)
- [NixOS proxychains-ng package](https://search.nixos.org/packages?query=proxychains-ng)
- [Tor Project](https://www.torproject.org/)

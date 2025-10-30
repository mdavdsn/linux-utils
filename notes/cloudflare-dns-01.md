# Cloudflare DNS-01

Set up DNS-01 challenge for Let's Encrypt using Cloudflare. Useful for subdomains that point to reverse proxies.

## Install Certbot with Cloudflare Plugin

Ubuntu/Debian:
```bash
apt update
apt install certbot python3-certbot-dns-cloudflare
```
REHL/AlmaLinux 9:
```bash
dnf install certbot python3-certbot-dns-cloudflare
```

## Create Cloudflare API Token

1. Log into your Cloudflare dashboard.
2. Go to the user menu at the top right > My Profile > API Tokens > Create Token.
3. Use the Edit Zone DNS template to create the token.
  * Permissions `Zone`: `DNS`: `Edit`
  * Zone Resources Include: Specific Zone: `domain.tld`
4. Copy the API token.

## Create Credentials File

```bash
mkdir -p /root/.secrets
nano /root/.secrets/cloudflare.ini
```
Add the API token to the file:
```ini
# Cloudflare API token
dns_cloudflare_api_token = YOUR_API_TOKEN_HERE
```
Set file permissions:
```bin
chmod 600 /root/.secrets/cloudflare.ini
```

## Obtain Certificate Using DNS-01

```bash
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/cloudflare.ini -d subdomain.domain.tld --preferred-challenges dns-01
```
The certificate will be saved to `/ets/letsencrypt/live/subdomain.domain.tld/`.

## Configure Open LiteSpeed to Use the Certificate

In Open LiteSpeed Web Admin:
1. Go to Listeners > Your SSL Listener
2. Under SSL tab:
  * Private Key File: `/etc/letsencrypt/live/subdomain.domain.tld/privkey.pem`
  * Certificate File: `/etc/letsencrypt/live/subdomain.domain.tld/fullchain.pem`
3. Click the restart button

## Test Auto Renewal

```bash
certbot renew --dry-run
```

## Verify Timer

Ubuntu/Debian:
```bash
systemctl status certbot.timer
```
REHL/AlmaLinux 9:
```bash
systemctl status certbot-renew.timer
```

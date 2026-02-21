# Open LiteSpeed Web Admin Reverse Proxy

## Create Virtual Host

Create virtual host directories on the server (root, document). Obtain SSL using DNS-01. On webadmin, create a new virtual host with the desired subdomain as the name. Go to the External Apps tab.
1. Add new `Web Server`.
2. Name: `webadmin`.
3. Address: `https://localhost:7080`.
4. Max Connections: `10`.
5. Under Context tab, add new `Proxy`.
6. URI: `/`.
7. Web Server: `webadmin`.

Next, go to Rewrite tab and choose `Yes` for Enable Rewrite and Auto Load from .htaccess. For the Rewrite rule, use:
```apache
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
```

Under SSL tab, add the Private Key and Certificate File paths and select `Yes` for Chained Certificate. Save everything and do a graceful restart.

## Add to Listener

Go to the Listeners and add the new virtual host to both the http and https listeners. Save and do a graceful restart. Log out and test by going to the subdomain specified in the virtual host.

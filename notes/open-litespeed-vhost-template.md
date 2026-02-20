# Open LiteSpeed Virtual Host Template

## Create Directories

Create virtual host and document root directories:
```bash
$ mkdir -p /home/[USER]/www/[DOMAIN]/public_HTML
```
Create log directory:
```bash
$ mkdir -p /home/[USER]/www/[DOMAIN]/logs
```

## Template configuration

Log in to OLS web admin and go to VHost Templates. Click the "+" to add a new template:
* Template name: `vhostConfig`
* Template file: `$SERVER_ROOT/conf/templates/vhostConfig.conf`
* Mapped Listeners: `http, https`
* Click save, then "Click to Create" under Template File

Go to General tab > Base1:
* Default Virtual Host Root: `/home/[USER]/www/$VH_NAME`
* Config File: `$SERVER_ROOT/conf/vhosts/$VH_NAME/vhconf.conf`
* Click Save

Go to General tab > Base2
* Document Root: `$VH_ROOT/public_html`
* Click Save

Go to Log tab > Virtual Host Log:
* Use Server's Log: `No`
* File Name: `$VH_ROOT/logs/error.log`
* Log Level: `ERROR`
* Rolling Size: `10M`
* Keep Days: `7`
* Compress Archive: `Yes`
* Click Save

Go to Log tab > Access Log:
* Log Control `Own Log File`
* File Name: `$VH_ROOT/logs/access.log
* Rolling Size: `10M`
* Keep Days: `7`
* Compress Archive: `Yes`
* Click Save

Go to Security tab > File Access Control:
* Follow Symbolic Link: `Yes`
* Enable Scripts/ExtApps: `Yes`
* Restrained: `Yes`
* Click Save

Go to External App tab:
* Click "+"
* Name: `$$VH_NAME_lsphp85`
* Address: `uds://tmp/lshttpd/$VH_NAME.sock`
* Max Connections: `3`
* Initial Timeout: `60`
* Retry Timeout: `30`
* Response Buffering: `No`
* Start By Server: `Yes (Through CGI Daemon)`
* Command: `/usr/local/lsws/lsphp85/bin/lsphp`
* Run As User: `$VH_NAME`
* Run As Group: `$VH_NAME`
* Click Save

Go to Script Handler tab:
* Click "+"
* Suffixes: `php`
* Handler Type: `LiteSpeed SAPI`
* handler Name: `[VHost Level]: $VH_NAME_lsphp85`
* Click Save

Go to Rewrite tab:
* Enable Rewrite: `Yes`
* Auto Load fomr .htaccess: `Yes`
* Click Save

Go to Rewrite tab > Rewrite Rules:
```apache
RewriteCond %{HTTPS} !on
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
```
* Click Save

Go to SSL tab:
* Private Key File: `/etc/letsencrypt/live/$VH_NAME/privkey.pem`
* Public Key File: `	/etc/letsencrypt/live/$VH_NAME/fullchain.pem`
* Chained Certificate: `Yes`
* Click Save

Perform a graceful restart, then click the Template tab. Under Member Virtual Hosts, click "+" and fill in the domain name for Virtual Host Name and Domain Name. Click Save and do a graceful restart.

## Test Configuration

SSH to the server and create a file to test the connection.
```bash
& echo "<h1>It's working</h1> > ~/www/[DOMAIN]/public_html/index.html
```
Visit the domain in a browser, making sure that the page loads and http is redirected to https.

# Server Hardening Runbook — Rocky Linux 8 / OpenLiteSpeed VPS

## ⚠️ Order matters — read this first

You're currently root-only, so if you disable root login or password auth before confirming your new user works, **you will lock yourself out** (unless you use Linode's Lish console to recover, which is annoying but possible).

**Rule for every step below that changes SSH access:** keep your current root/password session open in one terminal, and test the new method in a *second, fresh* terminal window before you touch the old method again. Don't close the original session until the new one is proven.

---

## Step 1 — Create a sudo user

```bash
useradd -m -s /bin/bash yourusername
passwd yourusername
usermod -aG wheel yourusername
```

Rocky ships with the wheel group already granted sudo in `/etc/sudoers` (`%wheel ALL=(ALL) ALL` uncommented). If `sudo -l` fails for the new user, run `visudo` and uncomment that line.

---

## Step 2 — Set up an SSH key

On your **local machine** (not the server):

```bash
ssh-keygen -t ed25519 -C "yourname@church-site"
ssh-copy-id yourusername@your-server-ip
```

If `ssh-copy-id` isn't available, do it manually on the server:

```bash
mkdir -p /home/yourusername/.ssh
# paste your public key into this file:
nano /home/yourusername/.ssh/authorized_keys
chmod 700 /home/yourusername/.ssh
chmod 600 /home/yourusername/.ssh/authorized_keys
chown -R yourusername:yourusername /home/yourusername/.ssh
```

**Test in a new terminal, keeping the old session open:**

```bash
ssh yourusername@your-server-ip
sudo whoami   # should print "root"
```

Don't move on until this works.

---

## Step 3 — Harden sshd_config (root login + password auth off)

Edit `/etc/ssh/sshd_config`:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowUsers yourusername
```

Restart, but don't close your current session:

```bash
sudo systemctl restart sshd
```

Open a **new** terminal and confirm you can still log in and sudo before closing the original session.

---

## Step 4 — fail2ban

```bash
sudo dnf install epel-release -y
sudo dnf install fail2ban -y
sudo systemctl enable --now fail2ban
```

Create `/etc/fail2ban/jail.local`:

```ini
[sshd]
enabled = true
port = ssh
backend = systemd
maxretry = 4
bantime = 1h
findtime = 10m
```

(You'll change `port = ssh` to your new port number in Step 5.)

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

---

## Step 5 — Move real SSH off port 22, put endlessh on port 22 as a tarpit

The idea: real sshd moves to a nonstandard port; endlessh sits on port 22 and slow-drips bytes at bots forever, wasting their time and (with rate-limited scanners) getting them to give up.

**a) Move sshd's port.** In `/etc/ssh/sshd_config`:

```
Port 2222
```

(Pick any unused port.) Then, since Rocky runs SELinux enforcing by default:

```bash
sudo dnf install policycoreutils-python-utils -y
sudo semanage port -a -t ssh_port_t -p tcp 2222
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --reload
sudo systemctl restart sshd
```

**Test from a new terminal before closing your session:**

```bash
ssh -p 2222 yourusername@your-server-ip
```

**b) Update fail2ban** to watch the new port — edit `/etc/fail2ban/jail.local`:

```
port = 2222
```

```bash
sudo systemctl restart fail2ban
```

**c) Install endlessh** (not in the default repos — build from source, it's a tiny codebase with no dependencies beyond a C compiler):

```bash
sudo dnf groupinstall "Development Tools" -y
cd /usr/local/src
sudo git clone https://github.com/skeeto/endlessh.git
cd endlessh
sudo make
sudo cp endlessh /usr/local/bin/
```

Config file `/etc/endlessh/config`:

```bash
sudo mkdir -p /etc/endlessh
sudo tee /etc/endlessh/config <<'EOF'
Port 22
Delay 10000
MaxLineLength 32
MaxClients 4096
LogLevel 1
EOF
```

Systemd unit `/etc/systemd/system/endlessh.service`:

```ini
[Unit]
Description=endlessh SSH tarpit
After=network.target

[Service]
ExecStart=/usr/local/bin/endlessh -f /etc/endlessh/config
AmbientCapabilities=CAP_NET_BIND_SERVICE
DynamicUser=yes
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now endlessh
sudo systemctl status endlessh
```

Port 22 is already open in firewalld by default, so no firewall change needed for endlessh itself. If `journalctl -u endlessh` shows SELinux denials (unlikely for a plain custom unit, but possible), run:

```bash
sudo ausearch -m avc -ts recent | audit2allow -M endlessh_local
sudo semodule -i endlessh_local.pp
```

---

## Step 6 — Other recommended hardening

- **Automatic security patches:**
  ```bash
  sudo dnf install dnf-automatic -y
  sudo sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
  sudo systemctl enable --now dnf-automatic.timer
  ```
- **Firewall scope:** confirm firewalld's default zone only allows what you actually need — web (80/443), your new SSH port, port 22 (for endlessh), and nothing else. Don't expose the OpenLiteSpeed admin panel (7080) publicly — restrict it to your own IP with a firewalld rich rule, or just tunnel to it over SSH when you need it.
- **WordPress-specific** (since your site runs Participants Database, presumably on WP): keep core/plugins updated, consider disabling XML-RPC if you don't use it, and add fail2ban coverage for repeated failed logins on `wp-login.php` if you see that in your Cloudflare/access logs.
- **Cloudflare:** if this domain is proxied through Cloudflare (orange cloud), make sure the origin IP isn't leaking anywhere (old DNS records, direct-IP references, etc.) — a hidden origin means less surface for random scanners to even find your SSH port in the first place. Note this only affects HTTP(S) traffic; it does nothing for SSH, since Cloudflare doesn't proxy that.
- **Backups:** before doing any of the above, confirm you have a recent working backup or Linode snapshot, just in case.
- **Optional extra layer:** PAM-based 2FA for SSH via `google-authenticator`, if you want belt-and-suspenders on top of key-only auth.
- **Spot-check activity periodically:** `last`, `lastb`, and `sudo fail2ban-client status sshd` will show you what's actually getting banned.

---

## Recap of the safe order

1. Create sudo user → 2. SSH key + test login → 3. Disable password/root login (test again) → 4. fail2ban → 5. Move SSH port + endlessh tarpit on 22 (test again) → 6. Everything else.

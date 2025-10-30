# Figma Agent for Linux

## Installation

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/neetly/figma-agent-linux/main/scripts/install.sh)"
```

## Uninstallation

```
systemctl --user disable --now figma-agent.{service,socket}
rm -rf ~/.local/share/figma-agent ~/.local/share/systemd/user/figma-agent.{service,socket} ~/.cache/figma-agent
```

## Troubleshooting

### Ad Blocker

Please check to see if any rules block figma.com from accessing localhost, such as [Block Outsider Intrusion into LAN](https://github.com/uBlockOrigin/uAssets/blob/master/filters/lan-block.txt).

### Brave Browser

Please grant figma.com permission to access localhost.
https://brave.com/privacy-updates/27-localhost-permission/

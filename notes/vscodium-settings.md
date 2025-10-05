# VS Codium Settings

Various settings for VS Codium

## Integrated Terminal Using SSH

1. Install `openssh-server` and enable it.
2. Create the key and authorize it to the local account.
```
ssh-keygen
ssh-copy-id localhost
```
3. Open VS Codium settings and go to Terminal.Integrated and search for the default profile for Linux. Click "Open settings.json" and place the following in the file and save.
```
"terminal.integrated.profiles.linux": {
        "ssh": {
            "path": "ssh",
            "args": ["localhost", "-t", "cd ${workspaceFolder}; bash -l"]
        },
    },
    "terminal.integrated.defaultProfile.linux": "ssh"
}
```
4. Restart VS Codium.

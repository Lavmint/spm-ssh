# SSH

Make sure that you install libssh from brew package manger

`brew install libshh`

# Usage

```
let ssh = SSH()
ssh.session.host.set(value: "localhost")
ssh.session.port.set(value: 22)
ssh.session.user.set(value: "user")
do {
    try ssh.session.execute(command: "open /Applications/Safari.app", password: "password")
} catch { }
```

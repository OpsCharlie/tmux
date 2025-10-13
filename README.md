# tmux

My tmux configuration files.

## Remote Copy Setup

To enable remote copy (copy from remote tmux in ssh):

### SSH Configuration

Add to your `.ssh/config`:

```conf

Host *
    RemoteForward 5556 localhost:5556
```

### On Local Machine

Run this command to listen for clipboard data:

```bash
while (true); do nc -l 5556 | xsel -b -i; done
```

### On Remote Machine

Use `Ctrl-a y` in tmux to copy selection to local clipboard.


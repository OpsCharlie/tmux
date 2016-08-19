# tmux
My tmux config

To enable remote copy (copy from remote tmux in ssh)

.ssh/config:
  Host *
      RemoteForward 5556 localhost:5556



On the local pc:
   while (true); do nc -l 5556 | xsel -b -i; done



On the remote tmux to copy to local clipboard
   Ctrl-a y




A simple init system written in Pascal. Services are started from plaintext scripts with udev and agetty being started from within the init itself. Written for Alpine Linux but portable to Void and probably many others with path adjustments. System will run with less than 8 processes and all services besides udev are optional.

To install, compile with fpc and copy to /sbin/pinit. Then symlink to /sbin/init.

All scripts are contained within /etc/pinit and you must create them. Log files are located within the same folder.
The three scripts that need to be created and made executable are: 

/etc/pinit/init_networking

/etc/pinit/init_services

/etc/pinit/init_misc


They must contain #!/bin/sh identifier.

Networking contains things like ip link set xxx up and udhcpc or whatever you prefer.
Services are where you launch services like sshd, rpcbind etc.
Misc is where you set things like your hostname and hwclock sync.

I am making my own distro based on alpine using this init currently. Everything I use functions just fine. Boot time is instant and service management is easy.

This is in heavy development so use at your own risk. I am writing this to learn Pascal and systems programming as well as wanting full control over my system in a way I personally like. My use case has no need for service supervision and such luxuries. Current issues on alpine are poweroff does nothing and reboot powers off. I will rewrite shutdown scripts in the future.

#!/bin/bash
set -eux

# show the default password settings.
samba-tool domain passwordsettings show

# add the alice.doe as a Domain Admin.
samba-tool user create alice.doe HeyH0Password
samba-tool group addmembers 'Domain Admins' alice.doe
wbinfo --name-to-sid alice.doe

# add the bob.doe as a regular user.
samba-tool user create bob.doe HeyH0Password
wbinfo --name-to-sid bob.doe

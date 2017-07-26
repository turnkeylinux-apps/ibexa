#!/usr/bin/python
"""Set eZ Platform admin password, email and domain to serve

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively


"""

import os
import re
import sys
import getopt
import inithooks_cache

import hashlib

from dialog_wrapper import Dialog
from mysqlconf import MySQL
from executil import system


def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)


def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email='])
    except getopt.GetoptError, e:
        usage(e)

    password = ""
    email = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "eZ Platform Password",
            "Enter new password for the eZ Platform 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "eZ Platform Email",
            "Enter email address for the eZ Platform 'admin' account.",
            "admin@example.com")

    inithooks_cache.write('APP_EMAIL', email)
    # tweak configuration files
    # calculate password hash and tweak database
    hash = hashlib.md5("admin\n%s" % password).hexdigest()

    m = MySQL()
    m.execute('UPDATE ezplatform.ezuser SET password_hash="%s" WHERE login="admin";' % hash)
    m.execute('UPDATE ezplatform.ezuser SET email="%s" WHERE login="admin";' % email)

    m.execute('UPDATE ezplatform.ezcontentobject_name SET name="TurnKey Linux eZ Platform" WHERE contentobject_id="1"')

if __name__ == "__main__":
    main()


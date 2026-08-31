Ibexa DXP (formerly eZ Platform) - Enterprise Content Management System
=======================================================================

`Ibexa`_ is a web content management system that supports the
development of customized web applications. It features professional and
secure development of web applications, content versioning, media
library, role-based rights management, mobile development, sitemaps,
search and printing.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Ibexa configurations:
   
   - Ibexa Open Source 4.6 LTS is installed from the official upstream source
     at ``/var/www/ibexa``.

   **Security note**: Updates to Ibexa may require supervision so
   they **ARE NOT** configured to install automatically. See `Ibexa
   documentation`_ for the supported update procedure.

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
   12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

For Ibexa news and updates, including security updates, we
recommend that you subscribe to the `Ibexa Blog`_.

Credentials *(passwords set at first boot)*
-------------------------------------------

- Webmin, SSH, MySQL: username **root**
- Adminer: username **adminer**
- Ibexa: username is **admin**


.. _Ibexa: https://ibexa.co
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Adminer: https://www.adminer.org/
.. _Ibexa documentation: https://doc.ibexa.co/en/4.6/updating/update_ibexa_dxp/
.. _Ibexa blog: https://www.ibexa.co/blog

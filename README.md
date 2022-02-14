# StumpyNIO

This library contains definitions for an SMTP server and a POP3 server, backed by a mail store
which will hold up to some fixed number of messages. The servers do not actually perform
authentication or forwarding, nor are there per-user mailboxes. The point of these servers
is to provide a straightforward way to test email sending and retrieval during testing and
development of other applications.

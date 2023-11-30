#!/bin/bash

# Crea el socket UNIX
SOCKET=/tmp/apache.sock

# Inicia socat para reenviar conexiones del socket UNIX a localhost:80
socat UNIX-LISTEN:$SOCKET,fork TCP:localhost:80 &

# Inicia Apache en el puerto 80
httpd-foreground

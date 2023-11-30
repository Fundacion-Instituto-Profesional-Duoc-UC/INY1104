# Usa una imagen base de Apache
FROM httpd:2.4

# Instala socat
RUN apt-get update && apt-get install -y socat

# Copia los archivos del sitio web al directorio de documentos de Apache
COPY ./e-commerce/ /usr/local/apache2/htdocs/

# Agrega un script de inicio personalizado
COPY ./start-apache.sh /usr/local/bin/

# Haz que el script de inicio sea ejecutable
RUN chmod +x /usr/local/bin/start-apache.sh

# Configura el comando de inicio para usar tu script
CMD ["/usr/local/bin/start-apache.sh"]

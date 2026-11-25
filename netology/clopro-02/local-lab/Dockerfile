FROM php:8.3-apache@sha256:fb5e44981a84757b95cd29440f534509f42a9766382c8c83bfd404924a62379b
RUN docker-php-ext-install mysqli
COPY app/index.php app/health.php /var/www/html/

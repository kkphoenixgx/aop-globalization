FROM public.ecr.aws/docker/library/php:8.2-cli
WORKDIR /app
COPY sdk sdk
COPY client.php .
RUN apt-get update && apt-get install -y git zip unzip
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN echo '{"name":"test/client","minimum-stability":"dev","require":{"panteao/client":"*"},"repositories":[{"type":"path","url":"./sdk"}]}' > composer.json
RUN composer install
CMD ["php", "client.php"]

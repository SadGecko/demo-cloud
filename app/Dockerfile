FROM ubuntu:20.04

RUN adduser wp

RUN apt update && apt upgrade -y
RUN apt install -y php-fpm php-mysql nginx supervisor

RUN mkdir -p /var/www/wordpress
COPY ./src /var/www/wordpress
RUN chown -R wp:wp /var/www/wordpress

COPY ./configs/wp-config.php /var/www/wordpress/wp-config.php
COPY ./configs/wp.conf /etc/php/7.4/fpm/pool.d/wp.conf
COPY ./configs/nginx /etc/nginx/sites-available/default
COPY ./configs/supervisord.conf /etc/supervisord.conf

CMD ["/usr/bin/supervisord", "-n"]
EXPOSE 80
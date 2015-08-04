
docker run --rm -it --volumes-from invenio_data_1 -v $(pwd):/backup busybox /bin/sh -c 'cd /var/lib/mysql && tar cvf - . | gzip > /backup/data_mysql.tar.gz '
docker run --rm -it --volumes-from invenio_data_1 -v $(pwd):/backup busybox /bin/sh -c 'cd /opt/invenio && rm -rf var/tmp/ && rm -rf var/tmp-shared && tar cvf - . | gzip > /backup/data_invenio.tar.gz'

# docker run --rm -it --volumes-from invenio_data_1 -v $(pwd):/backup busybox /bin/sh -c 'cd /var/lib/mysql && tar cvf /backup/data_mysql.tar .'
# docker run --rm -it --volumes-from invenio_data_1 -v $(pwd):/backup busybox /bin/sh -c 'cd /opt/invenio && tar cvf /backup/data_invenio.tar .'

docker build -t ddaze/invenio-legacy-data .

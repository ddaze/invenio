FROM busybox

RUN mkdir /src \
    && mkdir -p /opt/invenio \
    && mkdir -p /var/lib/mysql

COPY data_mysql.tar.gz /
COPY data_invenio.tar.gz /
# ADD data_src.tar /src


ADD docker-entrypoint.sh /

Volume /var/lib/mysql
Volume /opt/invenio
Volume /src

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["true"]

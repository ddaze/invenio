# This file is part of Invenio.
#
# Copyright (C) 2015 CERN.
#
# Invenio is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Invenio is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Invenio; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

FROM ubuntu

# Installing OS prerequisites:
RUN apt-get update -y && \
    apt-get install -y automake \
                   # python-flake8 \
                   # python-gnuplot \
                   # python-gnuplot \
                   # python-h5py \
                   # python-libxml2 \
                   # python-libxslt1 \
                   # python-lxml \
                   # python-matplotlib \
                   # python-nose \
                   # python-numpy \
                   # python-pip \
                   # python-rdflib \
                   # sbcl \
                   ca-certificates \
                   cython \
                   file \
                   gcc \
                   gettext \
                   git \
                   gnuplot poppler-utils \
                   ipython \
                   less \
                   libfreetype6-dev \
                   libhdf5-dev \
                   libmysqlclient-dev \
                   libxft-dev \
                   libxml2-dev \
                   libxslt1-dev \
                   mlocate \
                   libpng12-dev \
                   mysql-client \
                   pdftk \
                   poppler-utils \
                   python-dev \
                   python-ipdb \
                   python-magic \
                   python-mysqldb \
                   python-virtualenv \
                   tar \
                   unzip \
                   vim \
                   w3m \
                   wget \
#    && apt-get build-dep -y python-matplotlib \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Installing Python prerequisites:
ENV virtenv /opt/virtenv
RUN virtualenv /opt/virtenv

ADD requirements.txt /tmp/requirements.txt
ADD requirements-extras.txt /tmp/requirements-extras.txt
RUN "$virtenv"/bin/pip install --upgrade distribute \
    && "$virtenv"/bin/pip install invenio-devserver \
    && "$virtenv"/bin/pip install -r /tmp/requirements.txt \
    && "$virtenv"/bin/pip install -r /tmp/requirements-extras.txt --allow-external gnuplot-py \
                                                 --allow-unverified gnuplot-py

# Run container as `apache` user, with forced UID of 1000, which
# should match current host user in most situations:
RUN useradd -m -u 1000 apache \
    && echo "export PATH+=:/src/invenio-devscripts" >> $(getent passwd apache | cut -f6 -d:)/.bashrc \
    && echo "export PATH+=:/opt/invenio/bin" >>  $(getent passwd apache | cut -f6 -d:)/.bashrc \
    && echo "alias ll='ls -alF'" >>  $(getent passwd apache | cut -f6 -d:)/.bashrc

ADD docker/serve.patch /tmp/
# Creating Python symlink:
RUN mkdir -p /opt/invenio/lib/python/invenio \
    && ln -s /opt/invenio/lib/python/invenio /opt/virtenv/lib/python2.7/site-packages/ \
    && patch -t /opt/virtenv/local/lib/python2.7/site-packages/invenio_devserver/serve.py < /tmp/serve.patch
#    && ln -s /opt/invenio/lib/python/invenio /opt/virtenv/local/lib/python2.7/site-packages/
#    && chown -R apache.apache /opt/invenio \
#    && mkdir /.texmf-var \
#    && chown apache /.texmf-var



# Adding current directory as `/code`; assuming people have `master` branch checked out:
# (note: this invalidates cache, but most of hard yum install is done by now)
RUN mkdir -p /src/invenio && chown -R apache /src
WORKDIR /src/invenio

ADD docker-entrypoint.sh /
ADD create-config /
ADD docker/invenio-local_cds.template /tmp/
ADD docker/invenio-local.template /tmp/
# Starting the application:
#USER apache
#VOLUME['/src']
#VOLUME['/opt/invenio']
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["serve"]

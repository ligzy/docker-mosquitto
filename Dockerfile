FROM alpine:3.11.2

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL maintainer="Jeremy Li<lizhiyong1@soundai.com>" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="mosquitto MQTT Brocker with auth-plugin" \
      org.label-schema.description="This project builds mosquitto with auth-plugin. \
      It also has mosquitto_pub, mosquitto_sub and np." \
      org.label-schema.url="https://cloud.docker.com/u/jllopis/repository/docker/jllopis/mosquitto" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/jllopis/docker-mosquitto" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

#RUN apk add --no-cache bash
RUN apk add bash
RUN addgroup -S mosquitto && \
    adduser -S -H -h /var/empty -s /sbin/nologin -D -G mosquitto mosquitto

ENV PATH=/usr/local/bin:/usr/local/sbin:$PATH
ENV MOSQUITTO_VERSION=v1.6.8
#ENV LIBWEBSOCKETS_VERSION=v3.2.1
ENV LIBWEBSOCKETS_VERSION=v2.4.2

COPY run.sh /

RUN apk add --virtual buildDeps git cmake build-base openssl-dev c-ares-dev util-linux-dev hiredis-dev postgresql-dev curl-dev libxslt docbook-xsl automake autoconf libtool
RUN apk add hiredis postgresql-libs libuuid c-ares openssl curl ca-certificates mysql-client mariadb-dev 
#RUN apk add perl perl-net-ssleay perl-io-socket-ssl perl-libwww
#RUN wget https://github.com/mongodb/mongo-c-driver/releases/download/1.15.1/mongo-c-driver-1.15.1.tar.gz
#COPY mongo-c-driver-1.15.1.tar.gz ./
#RUN tar -xvf mongo-c-driver-1.15.1.tar.gz
#RUN wget https://github.com/mongodb/mongo-c-driver/releases/download/1.13.0/mongo-c-driver-1.13.0.tar.gz
COPY mongo-c-driver-1.13.0.tar.gz ./
RUN tar -xvf mongo-c-driver-1.13.0.tar.gz
RUN cd mongo-c-driver-1.13.0 && \
        cmake -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DENABLE_BSON:STRING=ON \
        -DENABLE_MONGOC:BOOL=ON \
        -DENABLE_SSL:STRING=OPENSSL \
        -DENABLE_AUTOMATIC_INIT_AND_CLEANUP:BOOL=OFF \
        -DENABLE_MAN_PAGES:BOOL=OFF \
        -DENABLE_TESTS:BOOL=ON \
        -DENABLE_EXAMPLES:BOOL=OFF \
        -DCMAKE_SKIP_RPATH=ON \
    && make \
    # Check mongo-c-driver build
    && MONGOC_TEST_SKIP_MOCK=on \
    MONGOC_TEST_SKIP_SLOW=on \
    MONGOC_TEST_SKIP_LIVE=on \
    make check \
    \
    # Install mongo-c-driver
    && make install
#RUN git clone https://github.com/mongodb/mongo-c-driver.git && \
#    cd mongo-c-driver && \
#    git checkout ${MONGOC_VERSION} && \
#    sh autogen.sh --with-libbson=bundled && \
#    make && \
#    make install && \
#    cd / 
RUN chmod +x /run.sh && \
    mkdir -p /var/lib/mosquitto && \
    mkdir -p /var/log/mosquitto && \
    mkdir -p /opt/mosquitto/log && \
    mkdir -p /opt/mosquitto/data && \
    touch /var/lib/mosquitto/.keep && \
    mkdir -p /etc/mosquitto.d  
RUN git clone -b ${LIBWEBSOCKETS_VERSION} https://github.com/warmcat/libwebsockets && \
    cd libwebsockets && \
    cmake . \
      -DCMAKE_BUILD_TYPE=MinSizeRel \
      -DLWS_IPV6=ON \
      -DLWS_WITHOUT_CLIENT=ON \
      -DLWS_WITHOUT_TESTAPPS=ON \
      -DLWS_WITHOUT_EXTENSIONS=ON \
      -DLWS_WITHOUT_BUILTIN_GETIFADDRS=ON \
      -DLWS_WITH_ZIP_FOPS=OFF \
      -DLWS_WITH_ZLIB=OFF \
      -DLWS_WITH_SHARED=OFF && \
    make -j "$(nproc)" && \
    rm -rf /root/.cmake && \
    cd .. && \
    git clone -b ${MOSQUITTO_VERSION} https://github.com/eclipse/mosquitto.git && \
    cd mosquitto && \
    make -j "$(nproc)" \
      CFLAGS="-Wall -O2 -I/libwebsockets/include" \
      LDFLAGS="-L/libwebsockets/lib" \
      WITH_SRV=yes \
      WITH_STRIP=yes \
      WITH_ADNS=no \
      WITH_DOCS=no \
      WITH_MEMORY_TRACKING=no \
      WITH_TLS_PSK=no \
      WITH_WEBSOCKETS=yes \
    binary && \
    install -s -m755 client/mosquitto_pub /usr/bin/mosquitto_pub && \
    install -s -m755 client/mosquitto_rr /usr/bin/mosquitto_rr && \
    install -s -m755 client/mosquitto_sub /usr/bin/mosquitto_sub && \
    install -s -m644 lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1 && \
    ln -sf /usr/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so && \
    install -s -m755 src/mosquitto /usr/sbin/mosquitto && \
    install -s -m755 src/mosquitto_passwd /usr/bin/mosquitto_passwd && \
    git clone https://github.com/vankxr/mosquitto-auth-plug && \
    cd mosquitto-auth-plug && \
    cp config.mk.in config.mk && \
    sed -i "s/BACKEND_CDB ?= no/BACKEND_CDB ?= no/" config.mk && \
    sed -i "s/BACKEND_MYSQL ?= no/BACKEND_MYSQL ?= yes/" config.mk && \
    sed -i "s/BACKEND_SQLITE ?= no/BACKEND_SQLITE ?= no/" config.mk && \
    sed -i "s/BACKEND_REDIS ?= no/BACKEND_REDIS ?= yes/" config.mk && \
    sed -i "s/BACKEND_POSTGRES ?= no/BACKEND_POSTGRES ?= yes/" config.mk && \
    sed -i "s/BACKEND_LDAP ?= no/BACKEND_LDAP ?= no/" config.mk && \
    sed -i "s/BACKEND_HTTP ?= no/BACKEND_HTTP ?= yes/" config.mk && \
    sed -i "s/BACKEND_JWT ?= no/BACKEND_JWT ?= no/" config.mk && \
    sed -i "s/BACKEND_MONGO ?= no/BACKEND_MONGO ?= yes/" config.mk && \
    sed -i "s/BACKEND_FILES ?= no/BACKEND_FILES ?= no/" config.mk && \
    sed -i "s/BACKEND_MEMCACHED ?= no/BACKEND_MEMCACHED ?= no/" config.mk && \
    sed -i "s/MOSQUITTO_SRC =/MOSQUITTO_SRC = ..\//" config.mk && \
    make -j "$(nproc)" && \
    install -s -m755 auth-plug.so /usr/lib/ && \
    install -s -m755 np /usr/bin/ && \
    cd / && rm -rf mosquitto && \
    rm -rf libwebsockets && \
    apk del buildDeps && rm -rf /var/cache/apk/*


ADD mosquitto.conf /etc/mosquitto/mosquitto.conf

# MQTT default port and default port over TLS
EXPOSE 1883 8883
# MQTT over websocket default port and default port over TLS
EXPOSE 9001 9002
EXPOSE 8080 8443

VOLUME ["/opt/mosquitto","/var/lib/mosquitto", "/etc/mosquitto", "/etc/mosquitto.d","/var/log/mosquitto"]

ENTRYPOINT ["/run.sh"]
CMD ["mosquitto"]

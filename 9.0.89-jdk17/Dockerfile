FROM tomcat:9.0.89-jdk17

LABEL maintainer="jesse@weisner.ca, github.com/deuterium, github.com/ontkanin"
LABEL build_id="1718921807"

WORKDIR /
# Add docker-entrypoint script base
ADD https://github.com/itsbcit/docker-entrypoint/releases/download/v1.5/docker-entrypoint.tar.gz /docker-entrypoint.tar.gz
RUN tar zxvf docker-entrypoint.tar.gz && rm -f docker-entrypoint.tar.gz \
 && chmod -R 555 /docker-entrypoint.* \
 && echo "UTC" > /etc/timezone \
 && ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
 && chmod 664 /etc/passwd \
              /etc/group \
              /etc/shadow \
              /etc/timezone \
              /etc/localtime \
 && chown 0:0 /etc/shadow \
 && chmod 775 /etc
## run.sh below requires complex test expressions "[[" vs "["
RUN sed -i 's,^#!/bin/sh,#!/bin/bash,' /docker-entrypoint.sh

# Add dockerize
ADD https://github.com/jwilder/dockerize/releases/download/v0.7.0/dockerize-alpine-linux-amd64-v0.7.0.tar.gz /dockerize.tar.gz
RUN [ -d /usr/local/bin ] || mkdir -p /usr/local/bin \
 && tar zxf /dockerize.tar.gz -C /usr/local/bin \
 && chown 0:0 /usr/local/bin/dockerize \
 && chmod 0555 /usr/local/bin/dockerize \
 && rm -f /dockerize.tar.gz

ENV DOCKERIZE_ENV production

# Add Tini
ADD https://github.com/krallin/tini/releases/download/v0.19.0/tini-static-amd64 /tini
RUN chmod +x /tini \
 && ln -s /tini /sbin/tini 

## Common Environment Variables
ENV DEBUG 0
ENV TZ America/Vancouver

## Deployment Environment Variables
ENV CATALINA_BASE="/app/tomcat"
ENV CONNECT_TIMEOUT 5
ENV PROXY=""
ENV RUN_DOCKERIZE 0
ENV RUN_POSTDEPLOYMENT 0
ENV RUN_VANILLA 0
ENV S3_URL=""
ENV S3_AK=""
ENV S3_SK=""

## Update, Install, Cleanup
RUN set -eux \
 && echo 'APT::Install-Suggests "0";'   >> /etc/apt/apt.conf.d/00-docker \
 && echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker \
 ## UPDATE
 && DEBIAN_FRONTEND=noninteractive apt-get update \
 ## INSTALL: packages
 && apt-get install -y --no-install-recommends \
    ## here goes a list of packages to install
    file \
    unzip \
 ## CLEANUP
 && apt-get autoremove -yqq --purge \
    ## here goes a list of packages to purge
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

## Scripts for Configuration and WAR data processing
COPY ../resources/scripts/run.d/*.sh /run.d/

## Main script
COPY ../resources/scripts/run.sh /docker-entrypoint.d/

## App directory, scrits, and permissions
RUN mkdir   -p /app \
 && chmod 0777 /app \
 && chown  0:0 /app \
 && chmod 0755 /run.d \
 && chown  0:0 /run.d \
 && chmod 0444 /run.d/*.sh \
 && chown  0:0 /run.d/*.sh

## Set working directory
WORKDIR /app

## Set entrypoint for scripts
ENTRYPOINT ["/tini", "--", "/docker-entrypoint.sh"]

## Run Tomcat Catalina
CMD [ "catalina.sh", "run" ]

FROM alpine:3.21.3

ARG KUBECTL_VERSION=v1.30.10

RUN apk add --update \
    jq \
    curl \
    openssl \
    bash \
  && rm -rf /var/cache/apk/*

RUN curl -sLO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
  chmod a+x kubectl && \
  mv kubectl /usr/local/bin

ADD kcadm/kcadm /usr/local/bin

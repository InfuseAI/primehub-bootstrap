FROM alpine:3.10

ARG KUBECTL_VERSION=v1.15.3

RUN apk add --update \
    jq \
    curl \
    openssl \
    bash \
  && rm -rf /var/cache/apk/*

RUN curl -sLO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
  chmod a+x kubectl && \
  mv kubectl /usr/local/bin

ADD kcadm/kcadm /usr/local/bin

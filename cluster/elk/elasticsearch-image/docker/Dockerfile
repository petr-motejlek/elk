FROM ubuntu:focal

ENV DEBIAN_FRONTEND=noninteractive
RUN true \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
  && curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - \
  && apt-add-repository "deb https://artifacts.elastic.co/packages/7.x/apt stable main" \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    elasticsearch \
  && rm -rf /var/lib/apt/lists/*

COPY elasticsearch.yml /etc/elasticsearch/

USER elasticsearch
ENTRYPOINT ["/usr/share/elasticsearch/bin/elasticsearch"]

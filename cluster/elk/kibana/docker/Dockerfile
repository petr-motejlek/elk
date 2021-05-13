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
    kibana \
  && rm -rf /var/lib/apt/lists/*

ENV KBN_PATH_CONF=/etc/kibana
COPY kibana.yml /etc/kibana/

USER kibana
ENTRYPOINT ["/usr/share/kibana/bin/kibana"]

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
    logstash \
  && rm -rf /var/lib/apt/lists/*

COPY logstash.yml /etc/logstash/
COPY pipeline.conf /etc/logstash/conf.d/

USER logstash
ENTRYPOINT ["/usr/share/logstash/bin/logstash"]
CMD ["--path.settings","/etc/logstash"]

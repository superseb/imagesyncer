FROM rancher/agent-base:v0.3.0

COPY ./rancher-entrypoint.sh /

ENTRYPOINT ["/rancher-entrypoint.sh"]

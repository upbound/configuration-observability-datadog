FROM gcr.io/datadoghq/agent:latest
RUN agent integration install -r -t datadog-upbound-uxp==1.0.0
COPY conf.yaml /etc/datadog-agent/conf.d/upbound_uxp.d/conf.yaml
COPY conf.yaml /etc/datadog-agent/conf.d/upbound_uxp.d/auto_conf.yaml
COPY conf.yaml /opt/datadog-agent/bin/agent/dist/conf.d/conf.yaml
COPY conf.yaml /opt/datadog-agent/bin/agent/dist/conf.d/auto_conf.yaml
RUN cat /etc/datadog-agent/conf.d/upbound_uxp.d/conf.yaml

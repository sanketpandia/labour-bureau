FROM grafana/grafana:latest

# Copy custom Grafana configuration
COPY grafana.ini /etc/grafana/grafana.ini

# Copy provisioning files
COPY provisioning/ /etc/grafana/provisioning/

# Set proper permissions
USER root
RUN chown -R grafana:grafana /etc/grafana
USER grafana

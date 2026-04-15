# syntax=docker/dockerfile:1
# Platform comes from: docker buildx build --platform linux/arm64|amd64 ...
# On Intel/AMD Windows, linux/arm64 needs QEMU (Docker Desktop usually provides it; if RUN fails
# with "exec format error", run: docker run --privileged --rm tonistiigi/binfmt --install all
# or build linux/amd64 if your AWS target is x86_64.)
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

# Install build tools for compiling dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements.txt
COPY requirements.txt .

# Use uv pip to install dependencies 
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system --no-cache -r requirements.txt
# Install AWS OpenTelemetry and boto3(needed for observability + AWS SDK access)
RUN pip install --no-cache-dir "aws-opentelemetry-distro>=0.10.1" boto3

# Copy app source code and pyproject.toml
COPY src/ ./src/
COPY pyproject.toml .
# OpenTelemetry environment variables for AgentCore observability.  
# Change this to unique name for your agent.
#ENV OTEL_SERVICE_NAME=vacation_planner_agent
ENV OTEL_METRICS_EXPORTER=otlp
# AWS openTelemetry Disctrubution.
ENV OTEL_PYTHON_DISTRO=aws_distro
ENV OTEL_PYTHON_CONFIGURATOR=aws_configurator
# Export Protocol.
ENV OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
ENV OTEL_TRACES_EXPORTER=otlp

# Enable Agent observability.
ENV AGENT_OBSERVABILITY=true
# Service identication.
ENV OTEL_TRACES_SAMPLER=always_on
ENV OTEL_RESOURCE_ATTRIBUTES=service.namespace=AgentCore,service.version=1.0

# Expose port
ARG SERVICE_NAME=vacation_planner_agent
ARG PORT=8080
ENV OTEL_SERVICE_NAME=${SERVICE_NAME}
EXPOSE ${PORT}


# Run with OpenTelemetry auto-instrumentation. This will automatically instrument supported libraries and send telemetry to the configured OTLP endpoint.
CMD ["opentelemetry-instrument", "python", "src/vacation_planner/crew.py"]

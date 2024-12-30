FROM maven:3.8.4-openjdk-17-slim AS build

WORKDIR /app

COPY . .

ARG OTEL_AGENT_VERSION=2.11.0
ARG OTEL_AGENT_URL=https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar
ARG OTEL_AGENT_SHA256=4cff4ab46179260a61fc0d884f3f170cfbd9d2962dd260be2cff31262d0c7618

RUN apt update && apt install -y wget && rm -rf /var/lib/apt/lists/* && \
    wget -O opentelemetry-javaagent.jar ${OTEL_AGENT_URL} --tries=3 --retry-connrefused --no-check-certificate && \
    echo "${OTEL_AGENT_SHA256} opentelemetry-javaagent.jar" | sha256sum -c -

RUN mvn clean package

FROM azul/zulu-openjdk-alpine:17-jre-headless

WORKDIR /app

COPY --from=build /app/target/*.jar app.jar
COPY --from=build /app/opentelemetry-javaagent.jar /app/opentelemetry-javaagent.jar

ENV JAVA_TOOL_OPTIONS="-javaagent:/app/opentelemetry-javaagent.jar"
ENV OTEL_LOGS_EXPORTER="none"
ENV OTEL_METRICS_EXPORTER="otlp"
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4318"
ENV OTEL_TRACES_EXPORTER="zipkin"
ENV OTEL_EXPORTER_ZIPKIN_ENDPOINT="http://zipkin:9411/api/v2/spans"

EXPOSE 8761

CMD ["java", "-jar", "app.jar"]
# The names must be the same name as the 'receivers[*].path' in the builder-config.yml without the `./` prefix
ARG LOGS_RECEIVER_NAME=ga-logs-receiver
ARG TRACES_RECEIVER_NAME=ga-traces-receiver
ARG ANNOTATIONS_RECEIVER_NAME=ga-annotations-receiver

FROM alpine/git AS clone
ARG LOGS_RECEIVER_NAME
ARG TRACES_RECEIVER_NAME
ARG ANNOTATIONS_RECEIVER_NAME

ARG LOGS_RECEIVER_CLONE_URL="https://github.com/v1v/opentelemetry-github-actions-log-receiver.git"
ARG TRACES_RECEIVER_CLONE_URL="https://github.com/v1v/opentelemetry-github-actions-receiver.git"
ARG ANNOTATIONS_RECEIVER_CLONE_URL="https://github.com/v1v/opentelemetry-github-actions-annotations-receiver.git"

ARG LOGS_RECEIVER_REF="ef11b639ed5a30fe8ddda6e9d28c9bc6e0001904"
ARG TRACES_RECEIVER_REF="aef60873a6a7cd1aaf26a532febe5db1ce502071"
ARG ANNOTATIONS_RECEIVER_REF="766c49049a48ca04940fbb4cb11d387d6a553d8d"

LABEL logs-receiver-ref="$LOGS_RECEIVER_REF"
LABEL traces-receiver-ref="$TRACES_RECEIVER_REF"
LABEL annotations-receiver-ref="$ANNOTATIONS_RECEIVER_REF"

RUN git clone "$LOGS_RECEIVER_CLONE_URL" "$LOGS_RECEIVER_NAME" \
    && cd "$LOGS_RECEIVER_NAME" \
    && git reset --hard "$LOGS_RECEIVER_REF"

RUN git clone "$TRACES_RECEIVER_CLONE_URL" "$TRACES_RECEIVER_NAME" \
    && cd "$TRACES_RECEIVER_NAME" \
    && git reset --hard  "$TRACES_RECEIVER_REF"

RUN git clone "$ANNOTATIONS_RECEIVER_CLONE_URL" "$ANNOTATIONS_RECEIVER_NAME" \
    && cd "$ANNOTATIONS_RECEIVER_NAME" \
    && git reset --hard  "$ANNOTATIONS_RECEIVER_REF"

FROM golang:1.23 AS build
ARG LOGS_RECEIVER_NAME
ARG TRACES_RECEIVER_NAME
ARG ANNOTATIONS_RECEIVER_NAME
RUN apt-get update && apt-get install yq -y --no-install-recommends
WORKDIR /app
COPY ./builder-config.yml .
RUN go install go.opentelemetry.io/collector/cmd/builder@v$(yq -r '.dist.otel_version' builder-config.yml)
COPY --from=clone /git/"$LOGS_RECEIVER_NAME" ./"$LOGS_RECEIVER_NAME"
COPY --from=clone /git/"$TRACES_RECEIVER_NAME" ./"$TRACES_RECEIVER_NAME"
COPY --from=clone /git/"$ANNOTATIONS_RECEIVER_NAME" ./"$ANNOTATIONS_RECEIVER_NAME"
COPY ./builder-config.yml .
RUN CGO_ENABLED=0 builder --config=builder-config.yml

FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /app/bin/otelcol-custom /

EXPOSE 19418/tcp

CMD ["/otelcol-custom"]
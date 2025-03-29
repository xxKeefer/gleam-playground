FROM erlang:28.0.0-alpine AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.9.1-erlang-alpine /bin/gleam /bin/gleam
RUN apk add --no-cache build-base
COPY . /app/
RUN cd /app && gleam export erlang-shipment

FROM erlang:28.0.0-alpine
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp
COPY --from=build /app/build/erlang-shipment /app
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]


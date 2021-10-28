FROM golang:1.16
ENV CGO_ENABLED=0
RUN go get github.com/go-delve/delve/cmd/dlv

FROM alpine:3.13

RUN     mkdir /enterprise-metrics
WORKDIR /enterprise-metrics
ADD     ./enterprise-metrics ./
ADD     ./enterprise-metrics-provisioner ./
ADD     ./.src ./src
COPY --from=0 /go/bin/dlv ./

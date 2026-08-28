FROM docker.io/hashicorp/terraform:latest@sha256:64360659224d6cbeb099eeed61aa66a80e02c18ba08c0243bd905165b47b088e

RUN apk add --no-cache curl
# Build Stage
FROM ocaml/opam:alpine AS build

WORKDIR /home/opam

# Install system dependencies
RUN sudo apk add --update --no-cache libev-dev openssl-dev gmp-dev

# Install dependencies
COPY z-docker-opam.opam z-docker-opam.opam
RUN opam install . --deps-only

# Build project
COPY . .
RUN opam exec -- dune build

# Run Stage
FROM alpine:latest AS run

RUN apk add --update --no-cache libev

COPY --from=build /home/opam/_build/default/app.exe /bin/app

ENTRYPOINT [ "/bin/app" ]

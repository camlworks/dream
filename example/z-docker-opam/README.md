# `z-docker-opam`

<br>

This example runs a simple Web app inside a [Docker](https://www.docker.com/) container using [opam](https://opam.ocaml.org/) as the package manager. The Dockerfile has a build stage based on [opam base images](https://hub.docker.com/r/ocaml/opam) and a run stage based on [alpine](https://hub.docker.com/_/alpine)

## Docker

Build the image `hello-dream` from `Dockerfile`
```
docker build . --tag hello-dream
```

create and run the container `hello-dream-container` with the image `hello-dream`
```
docker run --name hello-dream-container -p 8080:8080 hello-dream:latest
```

## Docker compose

Alternatively, you can use [docker-compose](https://docs.docker.com/compose/) to run the example:

```
docker compose up -d
```

and stop it via:

```
docker compose down
```

See also [**`z-docker-esy`**](../z-docker-esy) for using the `esy` package manager.

<br>

[Up to the example index](../#deploying)

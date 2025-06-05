# Splashy

A minimal web server that listens on multiple ports (8080, 8081, and 3001) simultaneously. The
server responds with a simple static splash page. This is intended to be used as a placeholder
image for Deployments created via RHADS-SSC.

## Usage

To run the server:

```bash
go run main.go
```

The server will start listening on:
- http://localhost:8080
- http://localhost:8081
- http://localhost:3001

## Config

The GIT_REPO environment variable is injected into the index page in order to provide additional
context to clients.
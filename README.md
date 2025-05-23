# Simple-assembly-webserver

Simple HTTP webserver written in x86-64 assembly that binds to port 80, forks a new process for each client, reads files on GET requests, and writes POST bodies to disk under the specified filename.


# Compile and run the server

```sh
as -o webserver.o webserver.s && ld -o webserver webserver.o

sudo ./webserver
```

# Test the server

## POST request

```sh
curl -X POST -d 'Hello World' 'http://localhost/tmp/test'
```

The file `/tmp/test` will be created and it will contain the string **Hello World**.

## GET request

```sh
curl 'http://localhost/tmp/test'
```

We will read the content of the file `/tmp/test` which should be **Hello World** from our previous post request.

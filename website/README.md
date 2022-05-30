# Website source files

## Local testing
This website has been containerized using the [php:apache](https://hub.docker.com/_/php/?tab=description) docker image.

To build the image, run the following command from the website directory:
```bash
docker build -t batchelor_website .
```

The run the image run the following command:
```bash
docker run -p 80:80 -it batchelor_website
```
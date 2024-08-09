#!/bin/sh
docker run -dp 8080:8080 --name myapp $(cat /tmp/image_tag)

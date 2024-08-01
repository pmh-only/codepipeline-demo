FROM alpine

WORKDIR /app

RUN apk add --no-cache nodejs

COPY ./main.js .

ENTRYPOINT [ "/usr/bin/node" ]
CMD [ "/app/main.js" ]

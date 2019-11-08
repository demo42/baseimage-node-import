FROM demo42t.azurecr.io/hub/node:9-alpine
WORKDIR /test
COPY ./test.sh .
CMD ./test.sh


FROM demo42t.azurecr.io/hub/node:9-alpine
WORKDIR /test
COPY ./test.sh .
CMD ./test.sh
RUN chmod +x ./test.sh



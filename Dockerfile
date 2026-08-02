FROM thevlang/vlang:alpine

WORKDIR /home/mog

COPY . .

RUN apk add github-cli bash
RUN gh auth login --with-token < gh_token.txt
RUN mkdir -p release && v -prod -o release/mog .

ENTRYPOINT [ "./release/mog", "release", "upload" ]

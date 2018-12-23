FROM crystallang/crystal:0.27.0
ADD . /src
WORKDIR /src
RUN crystal build --static --release -s src/website.cr

FROM debian:stretch-slim
RUN apt-get update \
	&& apt-get --no-install-recommends -y install ca-certificates \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=0 /src/website /
COPY --from=0 /src/docs/site /public/
EXPOSE 8080

RUN adduser --disabled-password --gecos "" docker
USER docker
CMD ["/website", "config.json", "-p 8080", "--ssl", "--ssl-key-file", "/origin_cert.priv", "--ssl-cert-file", "/origin_cert.pub"]
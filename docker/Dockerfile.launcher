FROM crystallang/crystal:0.27.0
ADD . /src
WORKDIR /src
RUN crystal build --release --static -s src/launcher.cr

FROM debian:stretch-slim
RUN apt-get update \
	&& apt-get --no-install-recommends -y install ca-certificates \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos "" docker
USER docker
COPY --from=0 /src/launcher /
ENTRYPOINT ["/launcher", "config.json"]
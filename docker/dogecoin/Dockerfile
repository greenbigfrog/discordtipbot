FROM ubuntu:14.04

RUN apt-get update \
	&& apt-get --no-install-recommends -y install curl=7.35.* ca-certificates=20170717~14.04.1 \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*
RUN dpkg-reconfigure locales && \
    locale-gen en_US.UTF-8 && \
    /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN adduser --disabled-password --home /dogecoin --gecos "" dogecoin
RUN echo "dogecoin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

WORKDIR /usr/local/src
RUN curl -L -o dogecoin-1.10.0-linux64.tar.gz https://github.com/dogecoin/dogecoin/releases/download/v1.10.0/dogecoin-1.10.0-linux64.tar.gz
RUN tar -xzvf dogecoin-1.10.0-linux64.tar.gz
RUN chmod +x dogecoin-1.10.0/bin/dogecoind dogecoin-1.10.0/bin/dogecoin-cli
RUN ln -s /usr/local/src/dogecoin-1.10.0/bin/dogecoind /usr/local/bin/dogecoind
RUN ln -s /usr/local/src/dogecoin-1.10.0/bin/dogecoin-cli /usr/local/bin/dogecoin-cli

COPY dogecoin.conf /dogecoin/.dogecoin/dogecoin.conf
RUN chown -R dogecoin:dogecoin /dogecoin/.dogecoin

USER dogecoin
WORKDIR /dogecoin

EXPOSE 22555 22556

CMD ["dogecoind"]
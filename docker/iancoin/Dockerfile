FROM ubuntu:14.04

RUN apt-get update \
	&& apt-get install --no-install-recommends -y software-properties-common \
	&& add-apt-repository ppa:bitcoin/bitcoin \
	&& apt-get update \
	&& apt-get --no-install-recommends -y install build-essential libtool autotools-dev autoconf pkg-config libssl-dev libdb4.8-dev libdb4.8++-dev libboost-all-dev git curl automake libevent-dev \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/src
RUN git clone https://github.com/iancoin/iancoin.git

WORKDIR /usr/local/src/iancoin
RUN ./autogen.sh
RUN ./configure --without-gui
RUN make
RUN make install

RUN adduser --disabled-password --home /iancoin --gecos "" iancoin
RUN echo "iancoin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

COPY iancoin.conf /iancoin/.iancoin/iancoin.conf
RUN chown -R iancoin:iancoin /iancoin/.iancoin/

USER iancoin
WORKDIR /iancoin

EXPOSE 13766

CMD ["iancoind", "-printtoconsole"]
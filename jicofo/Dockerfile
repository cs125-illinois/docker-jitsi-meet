ARG JITSI_REPO=jitsi
FROM ${JITSI_REPO}/jitsi-base-java

RUN \
	apt-dpkg-wrap apt-get update && \
	apt-dpkg-wrap apt-get install -y jicofo && \
	apt-cleanup

COPY rootfs/ /

VOLUME /config


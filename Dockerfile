ARG CRAWL_TAG=0.34.0

###########
# BUILDER #
###########

FROM python:3.14-alpine AS builder

ARG CRAWL_TAG \
    CRAWL_REPO=https://github.com/crawl/crawl

RUN apk add --no-cache \
        g++ \
        gcc \
        git \
        libpng-dev \
        make \
        ncurses-dev \
        perl \
    && pip install --no-cache-dir pyyaml

RUN mkdir /build \
    && cd /build \
    && git clone ${CRAWL_REPO} --depth 1 crawl \
    && cd crawl \
    && git fetch origin tag ${CRAWL_TAG} --no-tags \
    && git checkout tags/${CRAWL_TAG} -b ${CRAWL_TAG} \
    && git submodule update --init

RUN cd /build/crawl/crawl-ref/source \
    # Alpine patch https://github.com/crawl/crawl/issues/2446
    && sed -i 's/#ifndef __HAIKU__/#if !defined(__HAIKU__) \&\& defined(__GLIBC__)/' crash.cc \
    && make -j$(nproc --ignore=2) WEBTILES=y USE_DGAMELAUNCH=y

###########
# RUNTIME #
###########

FROM python:3.14-alpine AS runtime

ARG CRAWL_TAG

COPY --from=builder /build/crawl/crawl-ref/source/ /app/source/
COPY --from=builder /build/crawl/crawl-ref/settings/ /app/settings/
COPY --from=builder /build/crawl/crawl-ref/docs/ /app/docs/

WORKDIR /app/source

RUN apk add --no-cache gcc musl-dev \
    && pip install --no-cache-dir -r /app/source/webserver/requirements/base.py3.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV CRAWL_TAG=${CRAWL_TAG}

VOLUME ["/data"]
EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]

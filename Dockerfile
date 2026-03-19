# syntax=docker/dockerfile:1.7

ARG CRAWL_TAG=0.34.0

###########
# BUILDER #
###########

FROM python:3.13-alpine AS builder

ARG CRAWL_TAG \
    CRAWL_REPO=https://github.com/crawl/crawl

RUN --mount=type=cache,target=/var/cache/apk \
    --mount=type=cache,target=/root/.cache/pip \
    apk add \
        g++ \
        gcc \
        git \
        libpng-dev \
        make \
        ncurses-dev \
        perl \
    && pip install pyyaml

RUN mkdir /build \
    && git clone ${CRAWL_REPO} --depth 1 /build/crawl \
    && cd /build/crawl \
    && git fetch origin tag ${CRAWL_TAG} --no-tags \
    && git checkout tags/${CRAWL_TAG} -b ${CRAWL_TAG} \
    && git submodule update --init

RUN cd /build/crawl/crawl-ref/source \
    # Alpine patch https://github.com/crawl/crawl/issues/2446
    && sed -i 's/#ifndef __HAIKU__/#if !defined(__HAIKU__) \&\& defined(__GLIBC__)/' crash.cc \
    && make -j$(nproc) WEBTILES=y USE_DGAMELAUNCH=y

RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel -w /wheels -r /build/crawl/crawl-ref/source/webserver/requirements/base.py3.txt

###########
# RUNTIME #
###########

FROM python:3.13-alpine AS runtime

ARG CRAWL_TAG

COPY --from=builder /build/crawl/crawl-ref/source/ /app/source/
COPY --from=builder /build/crawl/crawl-ref/settings/ /app/settings/
COPY --from=builder /build/crawl/crawl-ref/docs/ /app/docs/

WORKDIR /app/source

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-deps /wheels/*.whl \
    && rm -rf /wheels

COPY --chmod=+x entrypoint.sh /app/entrypoint.sh

ENV CRAWL_TAG=${CRAWL_TAG}

VOLUME ["/data"]

ENTRYPOINT ["/app/entrypoint.sh"]

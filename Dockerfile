# syntax=docker/dockerfile:1.7

ARG CRAWL_TAG

###########
# BUILDER #
###########

FROM python:3.13-alpine AS builder

ARG CRAWL_TAG \
    CRAWL_REPO=https://github.com/crawl/crawl

RUN --mount=type=cache,target=/var/cache/apk \
    --mount=type=cache,target=/root/.cache/pip \
    apk add \
        curl \
        g++ \
        gcc \
        git \
        jq \
        libpng-dev \
        make \
        ncurses-dev \
        perl \
    && pip install pyyaml

RUN set -eux \
    && if [ -z "${CRAWL_TAG:-}" ]; then \
         CRAWL_TAG=$(curl -fsSL \
           "https://api.github.com/repos/crawl/crawl/releases/latest" \
           | jq -r '.tag_name'); \
       fi \
    && printf '%s' "${CRAWL_TAG}" > /tmp/crawl-tag \
    && mkdir /build \
    && git clone ${CRAWL_REPO} --depth 1 /build/crawl \
    && cd /build/crawl \
    && git fetch origin tag "${CRAWL_TAG}" --no-tags \
    && git checkout tags/"${CRAWL_TAG}" -b "${CRAWL_TAG}" \
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

COPY --from=builder /tmp/crawl-tag /app/crawl-tag
COPY --from=builder /build/crawl/crawl-ref/source/ /app/source/
COPY --from=builder /build/crawl/crawl-ref/settings/ /app/settings/
COPY --from=builder /build/crawl/crawl-ref/docs/ /app/docs/

WORKDIR /app/source

RUN --mount=type=cache,target=/var/cache/apk \
    apk add bash libstdc++ libgcc

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-deps /wheels/*.whl \
    && rm -rf /wheels

COPY --chmod=+x entrypoint.sh /app/entrypoint.sh

VOLUME ["/data"]

ENTRYPOINT ["/app/entrypoint.sh"]

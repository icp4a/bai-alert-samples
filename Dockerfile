##################################################################
# Licensed Materials - Property of IBM
#  5737-I23
#  Copyright IBM Corp. 2023. All Rights Reserved.
#  U.S. Government Users Restricted Rights:
#  Use, duplication or disclosure restricted by GSA ADP Schedule
#  Contract with IBM Corp.
##################################################################
ARG UBI_IMAGE_TAG=1.17-2

# Build initial stage 
FROM registry.access.redhat.com/ubi8/openjdk-11:${UBI_IMAGE_TAG} as build

ARG OCP_CLIENT_VERSION=4.12
ARG JQ_VERSION=1.6
ARG KAFKA_VERSION=3.5.2
ARG SCALA_VERSION=2.13
ARG KAFKA_DIR=/opt/kafka

# Install dependencies
USER root

RUN echo "--- Installation prerequisites" \
    && cd /tmp \
    && microdnf install wget gzip \
    && wget https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -O /usr/local/bin/jq \
    && chmod +x /usr/local/bin/jq \
    && wget -q https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-${OCP_CLIENT_VERSION}/openshift-client-linux.tar.gz \
    && tar -xf openshift-client-linux.tar.gz \
    && rm -rf openshift-client-linux.tar.gz \
    && mv /tmp/oc /usr/local/bin/ \
    && chmod +x /usr/local/bin/oc \
    && wget https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -O /tmp/kafka.tgz \
    && tar -xf kafka.tgz -C /opt \
    && mv /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_DIR} \
    && rm -rf kafka.tgz

USER 1001    

# Build final image
FROM registry.access.redhat.com/ubi8/openjdk-11:${UBI_IMAGE_TAG}

ARG KAFKA_DIR=/opt/kafka

COPY --from=build /usr/local/bin/oc /usr/local/bin/
COPY --from=build /usr/local/bin/jq /usr/local/bin/
COPY --from=build ${KAFKA_DIR} ${KAFKA_DIR}

ENV PATH="${PATH}:${KAFKA_DIR}/bin"
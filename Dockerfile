# Build image
FROM registry.access.redhat.com/ubi8/ubi:latest AS build_base
ARG APPNAME=move2kube
# Get Dependencies
WORKDIR /temp
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN curl -o go.tar.gz https://dl.google.com/go/go1.15.linux-amd64.tar.gz
RUN tar -xzf go.tar.gz && mv go /usr/local/
RUN yum install git make -y 
RUN mkdir -p $GOPATH/src $GOPATH/bin && chmod -R 777 $GOPATH
ENV WORKDIR=${GOPATH}/src/${APPNAME}
WORKDIR ${WORKDIR}
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY scripts/installdeps.sh scripts/installdeps.sh
RUN cd / && source ${WORKDIR}/scripts/installdeps.sh && cd -
COPY . .
# Build
RUN make build
RUN cp bin/${APPNAME} /bin/${APPNAME}

# Run image
FROM registry.access.redhat.com/ubi8/ubi:latest
COPY misc/centos.repo /etc/yum.repos.d/centos.repo
RUN yum update -y && yum install -y podman && yum clean all
COPY --from=build_base /bin/${APPNAME} /bin/${APPNAME}
COPY --from=build_base /bin/pack /bin/pack
COPY --from=build_base /bin/kubectl /bin/kubectl
COPY --from=build_base /bin/operator-sdk /bin/operator-sdk
VOLUME ["/wksps"]
#"/var/run/docker.sock" needs to be mounted for CNB containerization to be used.
# Start app
WORKDIR /wksps
CMD [${APPNAME}]
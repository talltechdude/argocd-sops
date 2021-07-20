FROM viaductoss/ksops:v2.5.7 as ksops-builder

FROM golang:1.16 as helm-sops-builder

# renovate: datasource=github-releases depName=camptocamp/helm-sops
ARG HELM_SOPS_VERSION=20201003-1
RUN git clone --branch=${HELM_SOPS_VERSION} --depth=1 https://github.com/camptocamp/helm-sops && \
    cd helm-sops && \
    go build

# patch argocd repo server to be able to decrypt secrets
FROM argoproj/argocd:v2.0.4

# renovate: datasource=github-releases depName=mozilla/sops
ARG SOPS_VERSION=v3.7.1
# renovate: datasource=github-releases depName=jkroepke/helm-secrets
ARG HELM_SECRETS_VERSION=v3.8.2

# Switch to root for the ability to perform install
USER root

COPY helm-wrapper.sh /usr/local/bin/
COPY argocd-repo-server-wrapper /usr/local/bin/
COPY --from=helm-sops-builder /go/helm-sops/helm-sops /usr/local/bin/

RUN apt-get update && \
    apt-get install -y \
    curl \
    gpg \
    nano \
    sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    curl -o /usr/local/bin/sops -L https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux && \
    chmod +x /usr/local/bin/sops && \
    cd /usr/local/bin && \


    # mv argocd-repo-server _argocd-repo-server && \
    # mv argocd-repo-server-wrapper argocd-repo-server && \
    # chmod 755 argocd-repo-server && \
    # mv helm _helm && \
    # mv helm2 _helm2 && \
    # mv helm-sops helm && \
    # ln helm helm2

    mv helm helm.bin && \
    mv helm2 helm2.bin && \
    mv helm-wrapper.sh /home/argocd/helm && \
    ln -s /home/argocd/helm helm && \
    chmod +rwx /home/argocd/helm && \
    ln helm helm2 && \
    chmod +rwx helm helm2

# Set the kustomize home directory
ENV XDG_CONFIG_HOME=$HOME/.config
ENV KUSTOMIZE_PLUGIN_PATH=$XDG_CONFIG_HOME/kustomize/plugin/

ARG PKG_NAME=ksops

# Override the default kustomize executable with the Go built version
COPY --from=ksops-builder /go/bin/kustomize /usr/local/bin/kustomize

# Copy the plugin to kustomize plugin path
COPY --from=ksops-builder /go/src/github.com/viaduct-ai/kustomize-sops/*  $KUSTOMIZE_PLUGIN_PATH/viaduct.ai/v1/${PKG_NAME}/

# Switch back to non-root user
USER argocd

RUN helm plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION}

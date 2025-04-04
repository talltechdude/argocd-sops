FROM viaductoss/ksops:v3.1.1 as ksops-builder

# patch argocd repo server to be able to decrypt secrets
FROM argoproj/argocd:v2.6.15

# renovate: datasource=github-releases depName=mozilla/sops
ARG SOPS_VERSION=v3.10.1
# renovate: datasource=github-releases depName=jkroepke/helm-secrets
ARG HELM_SECRETS_VERSION=v3.15.0

# Switch to root for the ability to perform install
USER root

COPY helm-wrapper.sh /usr/local/bin/

RUN apt-get update && \
    apt-get install -y \
    curl \
    gpg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    curl -o /usr/local/bin/sops -L https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux && \
    chmod +x /usr/local/bin/sops && \
    cd /usr/local/bin && \
    mv helm helm.bin && \
    mv helm-wrapper.sh helm && \
    chmod +rwx helm

# Set the kustomize home directory
ENV XDG_CONFIG_HOME=$HOME/.config
ENV KUSTOMIZE_PLUGIN_PATH=$XDG_CONFIG_HOME/kustomize/plugin/

ARG PKG_NAME=ksops

# Override the default kustomize executable with the Go built version
COPY --from=ksops-builder /go/bin/kustomize /usr/local/bin/kustomize

# Copy the plugin to kustomize plugin path
COPY --from=ksops-builder /go/src/github.com/viaduct-ai/kustomize-sops/*  $KUSTOMIZE_PLUGIN_PATH/viaduct.ai/v1/${PKG_NAME}/

# Switch back to non-root user
USER 999

# Install Helm-Secrets plugin
ENV HELM_PLUGINS="/home/argocd/.local/share/helm/plugins/"
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION}

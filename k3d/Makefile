.PHONY: pbrennan-gel gel-distributed gel-ssd loki-distributed loki-simple-scalable down secrets
.PHONY: add-repos update-repos create-registry prepare-gel prepare-loki build-latest-gel-image build-latest-loki-image

GEL_IMAGE_TAG := $(shell pushd ../../enterprise-logs/tools/ > /dev/null && ./image-tag)
LOKI_IMAGE_TAG := $(shell pushd ../../loki/tools/ > /dev/null && ./image-tag)
REGISTRY_PORT ?= $(shell k3d registry list -o json | jq -r '.[] | select(.name == "k3d-grafana") | .portMappings."5000/tcp" | .[0].HostPort')

pbrennan-gel: update-repos secrets prepare-gel
	$(CURDIR)/scripts/create_cluster.sh $(CURDIR)/environments/pbrennan-gel $(REGISTRY_PORT)

gel-distributed: update-repos secrets prepare-gel
	$(CURDIR)/scripts/create_cluster.sh $(CURDIR)/environments/gel-distributed $(REGISTRY_PORT)

enterprise-logs-simple: update-repos secrets prepare-gel
	$(CURDIR)/scripts/create_cluster.sh $(CURDIR)/environments/enterprise-logs-simple $(REGISTRY_PORT)

loki-distributed: update-repos prepare-loki
	$(CURDIR)/scripts/create_cluster.sh $(CURDIR)/environments/loki-distributed $(REGISTRY_PORT)

loki-simple-scalable: update-repos prepare-loki
	$(CURDIR)/scripts/create_cluster.sh $(CURDIR)/environments/loki-simple-scalable $(REGISTRY_PORT)

down:
	k3d cluster delete gel-distributed
	k3d cluster delete enterprise-logs-simple
	k3d cluster delete loki-distributed
	k3d cluster delete loki-simple-scalable
	k3d cluster delete pbrennan-gel

add-repos:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add grafana https://grafana.github.io/grafana/helm-charts
  helm repo add minio https://helm.min.io

update-repos: add-repos
	helm repo update
	tk tool charts vendor
	jb update

secrets: secrets/grafana.jwt secrets/gem.jwt secrets/gel.jwt secrets/secrets.json

secrets/grafana.jwt:
	op get document "grafana-license.jwt" > $(CURDIR)/secrets/grafana.jwt

secrets/gem.jwt:
	op get document "gem-license.jwt" > $(CURDIR)/secrets/gem.jwt

secrets/gel.jwt:
	op get document "gel-license.jwt" > $(CURDIR)/secrets/gel.jwt

secrets/secrets.json:
	op get document "grafana-envs-secrets.json" > $(CURDIR)/secrets/secrets.json

create-registry:
	@if ! k3d registry list | grep -q -m 1 grafana; then \
		echo "Creating registry"; \
		k3d registry create grafana --port $(REGISTRY_PORT); \
	else \
		echo "Registry already exists"; \
	fi

prepare-gel: create-registry update-repos build-latest-gel-image
prepare-loki: create-registry update-repos build-latest-loki-image

build-latest-loki-image:
	make -C $(CURDIR)/../../loki loki-image
	docker tag grafana/loki:$(LOKI_IMAGE_TAG) k3d-grafana:$(REGISTRY_PORT)/loki:latest
	docker push k3d-grafana:$(REGISTRY_PORT)/loki:latest

build-latest-gel-image:
	make -C $(CURDIR)/../../enterprise-logs enterprise-logs-image
	docker tag us.gcr.io/kubernetes-dev/enterprise-logs:$(GEL_IMAGE_TAG) k3d-grafana:$(REGISTRY_PORT)/enterprise-logs:latest
	docker push k3d-grafana:$(REGISTRY_PORT)/enterprise-logs:latest

package-gel-plugin:
	env_dir=$(CURDIR)
	pushd "$(HOME)/workspace/grafana/gex-plugins" || exit 1
	yarn
	pushd plugins/grafana-enterprise-logs-app || exit 1
	yarn build
	zip gel-plugin.zip dist/ -r
	cp gel-plugin.zip $env_dir/fixtures
	popd || exit 1
	popd || exit 1

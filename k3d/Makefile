.PHONY: gel-distributed loki-distributed loki-simple-scalable down add-repos update-repos secrets

gel-distributed: update-repos secrets
	make -C $(CURDIR)/environments/gel-distributed up

loki-distributed: update-repos
	k3dsonnet create --cluster loki-distributed
	tk env set ./environments/loki-distributed \
		--server="https://0.0.0.0:$$(k3d node list -o json | jq -r '.[] | select(.name == "k3d-loki-distributed-serverlb") | .portMappings."6443"[] | .HostPort')"
	kubectl config set-context k3d-loki-distributed
	kubectl create namespace loki-distribute || true
	k3dsonnet apply ./environments/loki-distributed

loki-simple-scalable: update-repos
	make -C $(CURDIR)/environments/loki-simple-scalable up

loki-ssd-jsonnet-libs: update-repos
	make -C $(CURDIR)/environments/loki-ssd-jsonnet-libs up

gel-ssd: update-repos secrets
	make -C $(CURDIR)/environments/gel-ssd up

down:
	make -C $(CURDIR)/environments/gel-distributed down
	make -C $(CURDIR)/environments/loki-distributed down
	make -C $(CURDIR)/environments/loki-simple-scalable down
	make -C $(CURDIR)/environments/loki-ssd-jsonnet-libs down
	make -C $(CURDIR)/environments/gel-ssd down

add-repos:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

update-repos: add-repos
	helm repo update
	tk tool charts vendor

secrets: secrets/grafana.jwt secrets/gem.jwt secrets/gel.jwt

secrets/grafana.jwt:
	op get document "grafana-license.jwt" > $(CURDIR)/secrets/grafana.jwt

secrets/gem.jwt:
	op get document "gem-license.jwt" > $(CURDIR)/secrets/gem.jwt

secrets/gel.jwt:
	op get document "gel-license.jwt" > $(CURDIR)/secrets/gel.jwt



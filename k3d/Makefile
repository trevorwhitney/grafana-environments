.PHONY: gel-distributed loki-distributed loki-simple-scalable down add-repos update-repos secrets

gel-distributed: update-repos secrets
	make -C $(CURDIR)/environments/gel-distributed up

loki-distributed: update-repos
	make -C $(CURDIR)/environments/loki-distributed up

loki-simple-scalable: update-repos
	make -C $(CURDIR)/environments/loki-simple-scalable up

down:
	make -C $(CURDIR)/environments/gel-distributed down
	make -C $(CURDIR)/environments/loki-distributed down
	make -C $(CURDIR)/environments/loki-simple-scalable down

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



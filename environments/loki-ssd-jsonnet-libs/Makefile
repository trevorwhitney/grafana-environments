.DEFAULT_GOAL := up

.PHONY: up down add-repos

up: add-repos
	./up.lua

down:
	k3d cluster delete loki-ssd-jsonnet-libs

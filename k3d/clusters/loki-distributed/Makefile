.DEFAULT_GOAL := up

.PHONY: up down add-repos

up: add-repos
	./up.lua

down:
	k3d cluster delete loki-distributed

add-repos:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

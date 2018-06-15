.PHONY: test

MINIKUBE_PROFILE=airflow
NAMESPACE ?= airflow-dev
CHART_LOCATION ?= charts/incubator/airflow/
HELM_RELEASE_NAME ?= airflow
HELM_VALUES_FILE ?= "airflow-minikube.yaml"

all: minikube-restart helm-install-traefik minikube-dashboard minikube-service-list helm-upgrade

restart: all

clean: minikube-stop minikube-delete

minikube-reset: minikube-delete minikube-restart

minikube-delete:
	# Force redownload of latest minikube ISO
	minikube -p $(MINIKUBE_PROFILE) delete

minikube-start:
	minikube -p $(MINIKUBE_PROFILE) start \
		--memory 8192

minikube-stop:
	minikube -p $(MINIKUBE_PROFILE) stop || true

minikube-restart: minikube-stop minikube-start wait helm-init

minikube-dashboard:
	minikube -p $(MINIKUBE_PROFILE) dashboard

minikube-service-list:
	minikube -p $(MINIKUBE_PROFILE) service list

minikube-browse-web:
	minikube -p $(MINIKUBE_PROFILE) service $(HELM_RELEASE_NAME)-web -n $(NAMESPACE)

minikube-url-web:
	minikube -p $(MINIKUBE_PROFILE) service $(HELM_RELEASE_NAME)-web -n $(NAMESPACE) --url

minikube-browse-flower:
	minikube -p $(MINIKUBE_PROFILE) service $(HELM_RELEASE_NAME)-flower -n $(NAMESPACE)

minikube-url-flower:
	minikube -p $(MINIKUBE_PROFILE) service $(HELM_RELEASE_NAME)-flower -n $(NAMESPACE) --url

helm-init:
	helm init --upgrade --wait --debug --history-max 10

helm-install-traefik:
	minikube -p $(MINIKUBE_PROFILE) addons enable ingress
	kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-deployment.yaml

helm-status:
	helm status $(HELM_RELEASE_NAME)

helm-upgrade: helm-upgrade-dep wait helm-upgrade-install

helm-upgrade-dep:
	helm dep build $(CHART_LOCATION)

helm-upgrade-install:
	helm upgrade --install \
		--wait\
		--debug \
		--recreate-pods \
		--namespace=$(NAMESPACE) \
		--timeout 600 \
		-f $(HELM_VALUES_FILE) \
		$(HELM_RELEASE_NAME) \
		$(CHART_LOCATION)

update-etc-host:
	./minikube-update-hosts.sh

test:
	make helm-upgrade HELM_VALUES_FILE=./test/minikube-values.yaml

test-and-update-etc-host: test update-etc-host

helm-lint:
	helm lint \
		$(CHART_LOCATION) \
		--namespace=$(NAMESPACE) \
		--debug \
		$(HELM_VALUES_ARG)

lint: helm-lint

helm-delete:
	helm delete --purge \
		$(HELM_RELEASE_NAME)

wait:
	sleep 60

minikube-full-test: minikube-restart wait helm-init helm-delete test

kubectl-get-services:
	kubectl get services --namespace $(NAMESPACE)

kubectl-list-pods:
	kubectl get po -a --namespace $(NAMESPACE)

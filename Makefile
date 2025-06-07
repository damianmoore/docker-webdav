# Docker image configuration
IMAGE_NAME := damianmoore/webdav
REGISTRY := docker.io
TAG ?= latest
PLATFORM ?= linux/amd64,linux/arm64

# Docker build arguments
DOCKER_BUILDX_ARGS := --platform $(PLATFORM)

# Default target
.PHONY: help
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: ## Build Docker image
	@echo "Building Docker image: $(REGISTRY)/$(IMAGE_NAME):$(TAG)"
	docker build -t $(REGISTRY)/$(IMAGE_NAME):$(TAG) .

.PHONY: build-multiarch
build-multiarch: ## Build multi-architecture Docker image using buildx
	@echo "Building multi-architecture Docker image: $(REGISTRY)/$(IMAGE_NAME):$(TAG)"
	docker buildx build $(DOCKER_BUILDX_ARGS) -t $(REGISTRY)/$(IMAGE_NAME):$(TAG) .

.PHONY: tag
tag: ## Tag the Docker image (requires TAG variable)
	@if [ "$(TAG)" = "latest" ]; then \
		echo "Warning: Tagging as 'latest'. Use TAG=<version> for specific versions."; \
	fi
	@echo "Tagging image: $(REGISTRY)/$(IMAGE_NAME):$(TAG)"
	docker tag $(REGISTRY)/$(IMAGE_NAME):latest $(REGISTRY)/$(IMAGE_NAME):$(TAG)

.PHONY: push
push: ## Push Docker image to DockerHub
	@echo "Pushing Docker image: $(REGISTRY)/$(IMAGE_NAME):$(TAG)"
	docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

.PHONY: push-multiarch
push-multiarch: ## Build and push multi-architecture Docker image using buildx
	@echo "Building and pushing multi-architecture Docker image: $(REGISTRY)/$(IMAGE_NAME):$(TAG)"
	docker buildx build $(DOCKER_BUILDX_ARGS) -t $(REGISTRY)/$(IMAGE_NAME):$(TAG) --push .

.PHONY: login
login: ## Login to DockerHub (requires DOCKER_USERNAME and DOCKER_PASSWORD env vars)
	@if [ -z "$(DOCKER_USERNAME)" ] || [ -z "$(DOCKER_PASSWORD)" ]; then \
		echo "Error: DOCKER_USERNAME and DOCKER_PASSWORD environment variables must be set"; \
		exit 1; \
	fi
	@echo "Logging in to DockerHub..."
	@echo "$(DOCKER_PASSWORD)" | docker login $(REGISTRY) -u "$(DOCKER_USERNAME)" --password-stdin

.PHONY: logout
logout: ## Logout from DockerHub
	@echo "Logging out from DockerHub..."
	docker logout $(REGISTRY)

.PHONY: clean
clean: ## Remove local Docker images
	@echo "Removing local Docker images..."
	-docker rmi $(REGISTRY)/$(IMAGE_NAME):$(TAG)
	-docker rmi $(REGISTRY)/$(IMAGE_NAME):latest

.PHONY: run
run: ## Run the Docker container locally for testing
	@echo "Running Docker container: $(REGISTRY)/$(IMAGE_NAME):$(TAG)"
	docker run --rm -p 8080:80 \
		-e WEBDAV_USERNAME=testuser \
		-e WEBDAV_PASSWORD=testpass \
		-e PUID=1000 \
		-e PGID=1000 \
		-e TZ=UTC \
		$(REGISTRY)/$(IMAGE_NAME):$(TAG)

.PHONY: test
test: build run ## Build and test the Docker image locally

.PHONY: release
release: build push ## Build and push the Docker image (single architecture)

.PHONY: release-multiarch
release-multiarch: push-multiarch ## Build and push multi-architecture Docker image

.PHONY: all
all: build tag push ## Build, tag, and push the Docker image

# Version-specific targets
.PHONY: version
version: ## Create a version tag (requires VERSION variable)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION variable must be set (e.g., make version VERSION=1.0.0)"; \
		exit 1; \
	fi
	$(MAKE) build TAG=$(VERSION)
	$(MAKE) tag TAG=$(VERSION)
	$(MAKE) push TAG=$(VERSION)
	$(MAKE) tag TAG=latest
	$(MAKE) push TAG=latest

# CI/CD friendly targets
.PHONY: ci-build
ci-build: ## CI build target
	docker buildx create --use --name builder || true
	$(MAKE) build-multiarch

.PHONY: ci-push
ci-push: ## CI push target (requires login)
	docker buildx create --use --name builder || true
	$(MAKE) push-multiarch

.PHONY: ci-release
ci-release: login ci-push logout ## Complete CI release pipeline

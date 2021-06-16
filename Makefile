IMAGE=infuseai/primehub-bootstrap:20191022

# Build the image
.PHONY: build
build:
	docker build -t $(IMAGE) .

# Push the image to repository
publish: build
	docker push $(IMAGE)

# Run into the built image with shell. For development purpose
run:
	@docker rm bootstrap >& /dev/null || true
	docker run --name bootstrap --rm -it --entrypoint /bin/bash $(IMAGE)

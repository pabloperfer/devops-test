.PHONY: lint build tag login push deploy

AWS_REGION = us-east-1
ACCOUNT_ID = 679349556244  
REPO_NAME = sample-node-app
IMAGE_TAG = latest

ECR_URI = $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(REPO_NAME)

lint:
	yamllint k8s/

build:
	docker build -t $(REPO_NAME):$(IMAGE_TAG) ./app

tag:
	docker tag $(REPO_NAME):$(IMAGE_TAG) $(ECR_URI):$(IMAGE_TAG)

login:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

push: tag login
	docker push $(ECR_URI):$(IMAGE_TAG)

deploy:
	kubectl apply -f k8s/

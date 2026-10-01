# fastapi_aws

FastAPI app deployed to AWS ECS Fargate via Jenkins, triggered by GitHub pushes.

## Flow
Push to `main` → GitHub webhook → Jenkins (on EC2) → build, test, scan →
Terraform (ECS/ECR/ALB/VPC) → push image to ECR → deploy to ECS.

## Repo layout
```
src/fastapi_aws/     app code
requirements.txt     root level
Dockerfile
Jenkinsfile
terraform/            main.tf, variables.tf, outputs.tf, backend.tf
create-jenkins-ec2.sh provisions the Jenkins EC2 box
create-tfstate-bucket.sh  also run automatically by the Jenkinsfile
deployment1.yaml      for local minikube testing only
teardown-all.sh       run from your own machine, not EC2
```

## One-time setup
1. `./create-jenkins-ec2.sh` from your local machine
2. SSH in, unlock Jenkins, install suggested plugins
3. Add a Jenkins credential, ID `aws-creds` (AWS access key/secret)
4. Create a Pipeline job manually:
   - **General**: check "GitHub project", URL `https://github.com/revglen/fastapi_aws/`
   - **Pipeline**: "Pipeline script from SCM" → Git → `https://github.com/revglen/fastapi_aws.git` → branch `*/main` → script path `Jenkinsfile`
   - **Build Triggers**: check "GitHub hook trigger for GITScm polling"
5. GitHub repo → Settings → Webhooks → add `http://<ec2-ip>:8080/github-webhook/`, content type `application/json`, push events

## Deploy
Just push to `main`. Jenkins does the rest, including creating the Terraform state bucket on first run.

## Check it's live
```
cd terraform
terraform output alb_dns_name
curl http://<that-dns-name>/health
```

## Local Kubernetes (minikube), separate from the AWS pipeline
```
minikube start

docker build -t fastapi-app:local .
minikube image load fastapi-app:local

kubectl apply -f deployment1.yaml

kubectl get pods
minikube service fastapi-app --url
```
`deployment1.yaml` uses `imagePullPolicy: Never` so it runs the locally-loaded
image instead of pulling from ECR. Nothing here touches Jenkins, Terraform, or
AWS, purely local testing. After a code change: rebuild, `minikube image load`
again, then `kubectl rollout restart deployment/fastapi-app`.

## Tear down
Infra only (keep the EC2/Jenkins box):
```
cd terraform
terraform destroy -auto-approve
```

Everything, including the EC2 instance, run from your local machine:
```
./teardown-all.sh
```
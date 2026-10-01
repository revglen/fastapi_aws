#!/bin/bash

set -euo pipefail

exec > /var/log/user-data.log 2>&1

apt update -y
apt install -y fontconfig openjdk-21-jre curl unzip gnupg software-properties-common apt-transport-https jq python3-venv  git

# ---- Docker ----
apt install -y docker.io
systemctl enable --now docker
usermod -aG docker jenkins || true

# ---- Jenkins ----
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt -y update
apt install -y jenkins
usermod -aG docker jenkins
systemctl enable --now jenkins

# ---- Terraform ----
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt update -y
apt install -y terraform

# ---- AWS CLI v2 ----
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# ---- Trivy (image scanning, used by the Jenkinsfile's Scan stage) ----
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list
apt update
apt install -y trivy

# ---- Plugins needed for the auto-created Pipeline job ----
jenkins-plugin-cli --plugins workflow-aggregator git github
 
# ---- Auto-create the Pipeline job on every Jenkins startup ----
# EDIT the repoUrl line below before launching the instance.
mkdir -p /var/lib/jenkins/init.groovy.d
cat > /var/lib/jenkins/init.groovy.d/create-pipeline-job.groovy << 'EOF'
import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*
import com.cloudbees.jenkins.GitHubPushTrigger
import org.jenkinsci.plugins.github.GithubProjectProperty
 
def jenkins = Jenkins.get()
def jobName = "fastapi-cicd-deploy"
 
if (jenkins.getItem(jobName) == null) {
    def repoUrl = "https://github.com/revglen/fastapi_aws.git"
 
    def job = jenkins.createProject(WorkflowJob.class, jobName)
 
    def scm = new GitSCM(repoUrl)
    scm.branches = [new BranchSpec("*/main")]
 
    def flowDef = new CpsScmFlowDefinition(scm, "Jenkinsfile")
    flowDef.lightweight = true
    job.definition = flowDef
 
    job.addProperty(new GithubProjectProperty(repoUrl))
    job.addTrigger(new GitHubPushTrigger())
    job.save()
 
    println "Created job: ${jobName}"
} else {
    println "Job ${jobName} already exists, skipping"
}
EOF
chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

systemctl restart jenkins
systemctl status jenkins

echo "DONE. Jenkins initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
#go into the dev-environment directory 
cd /home/ubuntu/dev-environment
./scripts/run-with-container.sh

#####
#AWS credentials found at /home/ubuntu/.aws/credentials.
#Are these credentials correct? (yes/no): yes
#Select your container runtime:
##1) docker
#2) podman
#3) nerdctl
#? 1
#Selected runtime: docker
#Choose an action:
#1) deploy
#2) destroy
#? 1


#  grab public IP address
aws ec2 describe-instances --filters "Name=tag:Name,Values=Bastion Host" --query "Reservations[].Instances[].PublicIpAddress" --output text

# SSH into the bastion 
ssh -i  ~/.ssh/dev-env.pem ubuntu@98.81.81.238
######################################################
# clone from your rep the files you need , 
git clone https://github.com/jondee/dev-environment.git

# do kubecolor 
vim ~/.bashrc
chmod 777 /home/ubuntu/dev-environment/kubecolor
alias kubectl=/home/ubuntu/dev-environment/kubecolor
source  ~/.bashrc

# Configure VPN from Bastion to Local ENvironment 
#copy the contents into a file on your desktop 
cat client1.ovpn
#####################################################

# get steps to modify the AMAZON AWS   with AWS CLI

#Get LB-ARN 
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text
#arn:aws:elasticloadbalancing:us-east-1:605134440110:loadbalancer/net/k8s-ingress-ingressn-d625bafb87/62be5e5c2dedf9e9

#get Main VPC-ID
aws elbv2 describe-load-balancers --load-balancer-arns "arn:aws:elasticloadbalancing:us-east-1:605134440110:loadbalancer/net/k8s-ingress-ingressn-d625bafb87/62be5e5c2dedf9e9" --query "LoadBalancers[0].VpcId" --output text
#vpc-0aaac808cd0fc88c1

# get DNS Name 
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].DNSName' --output text
# k8s-ingress-ingressn-d625bafb87-62be5e5c2dedf9e9.elb.us-east-1.amazonaws.com

# check existing hosted zones and delete to avoid confusion 

# use this to get the hosted-zone-id
# get the ListHostedZones
aws route53 list-hosted-zones --query 'HostedZones[*].[Id, Name]' --output table

----------------------------------------------------------
|                     ListHostedZones                    |
+------------------------------------+-------------------+
|  Z051552615M6X6LERTHKU |  devsecops.tolu.  |
|  Z005737333U5V4B5JCOOV |  devsecops.tolu.  |
+------------------------------------+-------------------+
# THis will delete prior Hosted Zones###############################################
#####################################################################################
#!/bin/bash

# List all hosted zones and get their IDs
HOSTED_ZONES=$(aws route53 list-hosted-zones --query "HostedZones[*].Id" --output text)

for ZONE_ID in $HOSTED_ZONES; do
    echo "Processing Hosted Zone: $ZONE_ID"

    # Get all record sets for this zone, excluding NS and SOA records
    aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
        --query "ResourceRecordSets[?!(Type == 'NS' || Type == 'SOA')]" \
        > records.json

    # Check if there are records to delete
    if [[ $(jq '. | length' records.json) -gt 0 ]]; then
        # Create a change batch file for deletion
        jq '{Changes: [.[] | {Action: "DELETE", ResourceRecordSet: .}]}' records.json > change-batch.json

        # Apply the change batch to delete records
        aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file://change-batch.json
    fi

    # Delete the hosted zone
    aws route53 delete-hosted-zone --id "$ZONE_ID"

    echo "Deleted Hosted Zone: $ZONE_ID"
done

echo "All hosted zones processed."
########################################################

# configure New  Route53 Hosted Zones 
aws route53 create-hosted-zone --name devsecops.tolu --caller-reference $(date +%s) --hosted-zone-config Comment="My Private Hosted Zone",PrivateZone=true --vpc VPCRegion=us-east-1,VPCId=vpc-0aaac808cd0fc88c1

# grab the hosted-zone id
aws route53 list-hosted-zones --query 'HostedZones[*].[Id, Name]' --output table
----------------------------------------------------------
|                     ListHostedZones                    |
+------------------------------------+-------------------+
|  Z06933552LG68F0J0S406 |  devsecops.tolu.              |
+------------------------------------+-------------------+


# configure record for Hosted zone , after pluggin in Zone-id , ingress Name 
#for below 
# change hosted-zone-id: Z06933552LG68F0J0S406
#change ingree value : k8s-ingress-ingressn-d625bafb87-62be5e5c2dedf9e9.elb.us-east-1.amazonaws.com
aws route53 change-resource-record-sets \
    --hosted-zone-id Z06933552LG68F0J0S406 \
    --change-batch '{
        "Changes": [{
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "*.devsecops.tolu",
                "Type": "CNAME",
                "TTL": 300,
                "ResourceRecords": [{
                    "Value": "k8s-ingress-ingressn-d625bafb87-62be5e5c2dedf9e9.elb.us-east-1.amazonaws.com"
                }]
            }
        }]
    }'

# exit from local and cd back into the AWS console   

################## GIT-LAB ##############################
####################################################
#set up git lab 
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm repo ls 


helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab --create-namespace \
  -f gitlab-values.yaml

# grab the gitlab secret 
k get secret gitlab-gitlab-initial-root-password -n gitlab -o yaml
echo -e "$(echo NFUxdzdFTmNoRERjc01tOUt0dW1IZDlWR2FQb2xHU0E5RGtGNjhzNnYxTmN0dzN3QlFiNVVHRHJURXpwMHVxRw== | base64 -d)\n"

username: root
password : 4U1w7ENchDDcsMm9KtumHd9VGaPolGSA9DkF68s6v1Nctw3wBQb5UGDrTEzp0uqG

####################LATEST SONARQUBE###############

#nimesh latest 
# Sonarqube
#https://github.com/SonarSource/helm-chart-sonarqube/tree/master/charts/sonarqube
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
# If you dont have permissions to create the namespace, skip this step and replace all -n with an existing namespace name.
kubectl create namespace sonarqube 
export MONITORING_PASSCODE="admin"
helm upgrade --install -n sonarqube sonarqube sonarqube/sonarqube --set monitoringPasscode=$MONITORING_PASSCODE,community.enabled=true -f sonar-values.yaml

#Password: Administrator1@

###########################################

###############OLD SONARQUBE######################################################
# Install sonarQube
#helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
#helm repo update
#kubectl create namespace sonarqube
#helm upgrade --install -n sonarqube  --version '~8' sonarqube sonarqube/sonarqube -f sonar-values.yaml


###########################################
# Argo CD 

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argo-ingress.yaml

#get argo password 
#username: admin
echo $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

####################################################
https://github.com/npandeya/snake-game.git


#####################################################

# Install Vault 
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault -f vault-values.yaml --create-namespace --namespace vault

#####################################################
# Install Observability ingress object for  ( Grafana, Prometheus, Tempo)
kubectl apply -f observability-ingress.yaml


#####################################################
#Install Neuvector
helm repo add neuvector https://neuvector.github.io/neuvector-helm/
helm search repo neuvector/core
helm install neuvector --namespace neuvector --create-namespace neuvector/core -f neuvector-values.yaml

#Default Neuvector 
username: admin 
password: admin
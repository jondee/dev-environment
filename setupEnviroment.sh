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
ssh -i  ~/.ssh/dev-env.pem ubuntu@100.27.214.212
######################################################
# clone from your rep the files you need , 
git clone https://github.com/jondee/dev-environment.git

# do kubecolor 
chmod 777 kubecolor
alias kubectl=/home/ubuntu/dev-environment/kubecolor

# Configure VPN from Bastion to Local ENvironment 
#copy the contents into a file on your desktop 
cat client1.ovpn
#####################################################

# get steps to modify the AMAZON AWS   with AWS CLI

#Get LB-ARN 
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text
#arn:aws:elasticloadbalancing:us-east-1:605134440110:loadbalancer/net/k8s-ingress-ingressn-3aa16fac58/6e91859e06e03e12

#get DNS NAME
aws elbv2 describe-load-balancers --load-balancer-arns "arn:aws:elasticloadbalancing:us-east-1:605134440110:loadbalancer/net/k8s-ingress-ingressn-3aa16fac58/6e91859e06e03e12" --query "LoadBalancers[0].DNSName" --output text
#k8s-ingress-ingressn-e58f8628fc-dda05663e8a2a3f0.elb.us-east-1.amazonaws.com

#get Main VPC-ID
aws elbv2 describe-load-balancers --load-balancer-arns "arn:aws:elasticloadbalancing:us-east-1:605134440110:loadbalancer/net/k8s-ingress-ingressn-3aa16fac58/6e91859e06e03e12" --query "LoadBalancers[0].VpcId" --output text
#vpc-0a7c8854ce59f501c

# get DNS Name 
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].DNSName' --output text
# k8s-ingress-ingressn-e58f8628fc-dda05663e8a2a3f0.elb.us-east-1.amazonaws.com

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
aws route53 create-hosted-zone --name devsecops.tolu --caller-reference $(date +%s) --hosted-zone-config Comment="My Private Hosted Zone",PrivateZone=true --vpc VPCRegion=us-east-1,VPCId=vpc-034960cec9b0a35a8




# configure record for Hosted zone , after pluggin in Zone-id , ingress Name 
aws route53 change-resource-record-sets \
    --hosted-zone-id Z04577351ZDI2VI2O8QOY \
    --change-batch '{
        "Changes": [{
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "*.devsecops.tolu",
                "Type": "CNAME",
                "TTL": 300,
                "ResourceRecords": [{
                    "Value": "k8s-ingress-ingressn-3aa16fac58-6e91859e06e03e12.elb.us-east-1.amazonaws.com"
                }]
            }
        }]
    }'




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
echo OTJMb2JlVDdVZXUzZHpiOGdvQkU4NWJaY0pVNk5SVVgxT3VvUk1qMEVOaGRhcnlkMzNaaE1mUlZIR1lnSGRlbw== | base64 -d


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
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
kubectl create namespace sonarqube
helm upgrade --install -n sonarqube  --version '~8' sonarqube sonarqube/sonarqube -f sonar-values.yaml


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

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

    ###
    ## REMOVE NAT GATEWAY
    ###
    export AWS_DEFAULT_REGION="us-west-2"
    AWS_VPC_ID=$(aws ec2 describe-vpcs --filter "Name=tag:Name,Values=$1" | jq '.Vpcs[].VpcId'| tr -d '"')
    echo "Deleting VPC with name $1 and VPCID $AWS_VPC_ID"
    echo "**********************************"
    echo "REMOVE NAT GATEWAY"
    echo "**********************************"
    NATGATEWAY=$(aws ec2 describe-nat-gateways  --filter "Name=vpc-id,Values=$AWS_VPC_ID" | jq '.NatGateways[].NatGatewayId' | tr -d '"')
    if [[ ! -z $NATGATEWAY ]]; then
        aws ec2 delete-nat-gateway --nat-gateway-id  $NATGATEWAY
        aws ec2  delete-tags --resources  $NATGATEWAY
        NATSTATE=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NATGATEWAY | jq '.NatGateways[].State' | tr -d '"')
        while [[ $NATSTATE == "deleting" ]]; do
            echo "Waiting for $NATGATEWAY to terminate.."
            sleep 60s
            NATSTATE=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NATGATEWAY | jq '.NatGateways[].State' | tr -d '"')
        done
    fi

    ###
    ##Remove Internet gateway from VPC
    ###
    echo "**********************************"
    echo "Remove Internet gateway from VPC"
    echo "**********************************"
    GATEWAY=$(aws ec2 describe-internet-gateways  --filters "Name=attachment.vpc-id,Values=$AWS_VPC_ID"  | jq '.InternetGateways[].InternetGatewayId'| tr -d '"')
    if [[ ! -z $GATEWAY ]]; then
        aws ec2 detach-internet-gateway --internet-gateway-id=$GATEWAY --vpc-id=$AWS_VPC_ID
        aws ec2 delete-internet-gateway --internet-gateway-id=$GATEWAY
        GATESTATE=$(aws ec2 describe-internet-gateways --internet-gateway-ids $GATEWAY | jq '.InternetGateways[].State' | tr -d '"')
        while [[ $GATESTATE == "deleting" ]]; do
          echo "Waiting for $GATEWAY to terminate.."
          sleep 30s
          echo $gate
          GATESTATE=$(aws ec2 describe-internet-gateways --internet-gateway-ids $GATEWAY | jq '.InternetGateways[].State' | tr -d '"')
        done
    fi



    ###
    ## Removing network interfaces
    ###
    DETACHNETWORKINTERFACE=$(aws ec2  describe-network-interfaces  --filters "Name=vpc-id,Values=$AWS_VPC_ID" | jq '.NetworkInterfaces[].Attachment.AttachmentId' | tr -d '"')
    for interface in $DETACHNETWORKINTERFACE; do
        echo "*********************************"
        echo "Detaching NIC: $interface FROM  $AWS_VPC_ID"
        echo "*********************************"
        aws ec2 detach-network-interface --attachment-id $interface
    done

    NETWORKINTERFACE=$(aws ec2  describe-network-interfaces  --filters "Name=vpc-id,Values=$AWS_VPC_ID" | jq '.NetworkInterfaces[].NetworkInterfaceId' | tr -d '"')
    for interface in $NETWORKINTERFACE; do
        echo "*********************************"
        echo "REMOVING NIC: $interface FROM  $AWS_VPC_ID"
        echo "*********************************"
        aws ec2 delete-network-interface --network-interface-id $interface
    done

    ###
    ##Remove Subnets from VPC
    ###
    echo "**********************************"
    echo "Remove Subnets from VPC"
    echo "**********************************"
    DELSUBNETID=$(aws ec2  describe-subnets --filters "Name=vpc-id,Values=$AWS_VPC_ID" | jq '.Subnets[].SubnetId' | tr -d '"')
    for subnetid in $DELSUBNETID; do
        echo "*********************************"
        echo "REMOVING $subnetid FROM  $AWS_VPC_ID"
        echo "*********************************"
        aws ec2 delete-subnet --subnet-id $subnetid
    done

    ###
    ##Removing Routing tables
    ###
    echo "**********************************"
    echo "Removing Routing tables"
    echo "**********************************"
    SUBNETTABLES=$(aws ec2  describe-route-tables  --filters "Name=vpc-id,Values=$AWS_VPC_ID" | jq '.RouteTables[].RouteTableId' | tr -d '"')
    for table in $SUBNETTABLES; do
        ###
        ##Remove Routing Table From VPC
        ###
        echo "*********************************"
        echo "Checking for ROUTE TABLE  IN $AWS_VPC_ID"
        echo "*********************************"
        aws ec2 delete-route --route-table-id  $table --destination-cidr-block 0.0.0.0/0
        aws ec2 delete-route-table --route-table-id  $table
    done

    ###
    ##Cleaning Elastic IPS
    ###
    echo "removing unused Elastic IPS"
    ITEMS=$(aws ec2  describe-addresses | jq '.Addresses[] | select(.NetworkInterfaceOwnerId==null) | .AllocationId' | tr -d '"')
    for x in $ITEMS; do
        echo "releasing $x"
        aws ec2 release-address --allocation-id $x
    done


    ###
    ##Remove VPC
    ###
    echo "**********************************"
    echo "DELETING VPC:$AWS_VPC_ID"
    echo "**********************************"
    aws ec2 delete-vpc --vpc-id $AWS_VPC_ID
    sleep 5s

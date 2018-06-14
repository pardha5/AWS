#!/bin/bash
n=0
until [ ! $n -lt 3 ]
do
	echo "$n execution"
	echo "Export Region"
	export AWS_DEFAULT_REGION="us-west-2"
	echo "Copying vars for vpc..."
	yes | cp -f vars1.yml vpc_vars1.yml
	yes | cp -f vars2.yml vpc_vars2.yml
	yes | cp -f vars3.yml vpc_vars3.yml
	echo "Creating VPC 1,2,3..."
	ansible-playbook vpc1.yml > vpc1$n.log 2>&1 &
	ansible-playbook vpc2.yml > vpc2$n.log 2>&1 &
	ansible-playbook vpc3.yml > vpc3$n.log 2>&1 &
	wait
	echo "###3 VPC Created"
	echo "###Starting Delete"
	./vpc_delete.sh test1-vpc > vpcd1$n.log 2>&1 &
	./vpc_delete.sh test2-vpc > vpcd2$n.log 2>&1 &
	./vpc_delete.sh test3-vpc > vpcd3$n.log 2>&1 &
	wait
	echo "###3 VPC Deleted"
	n=$((n+1))
done
echo "Completed $n times" 

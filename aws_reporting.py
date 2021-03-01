#!/usr/bin/env python
import boto
import boto.ec2
import sys
from boto.ec2.connection import EC2Connection
import pprint

account_string = "YOUR_ACCOUNT_STRING" #change this for each AWS account

class ansi_color: #unused class due to CSV file limitations
    red   = '\033[31m'
    green = '\033[32m'
    reset = '\033[0m'
    grey  = '\033[1;30m'

def instance_info(i):
    groups = ""
    volume_info = ""
    count = 1
    statusDummy = "Status Checks not available"
    alarmDummy = "Alarm Status not available"
    
    #logic for instance name
    if 'Name' in i.tags:
        name = str(i.tags['Name'])
        if name == "":
        	name = '!!! No name specified !!!'
    else:
        name = '??? Name not in attributes for instance ???'
        #n = n.ljust(16)[:16]
    #if i.state == 'running':
    #    n = ansi_color.green + n + ansi_color.reset
    #else:
    #    n = ansi_color.red + n + ansi_color.reset
    
    #logic for public DNS
    if i.state == 'running':
        pub_name = i.public_dns_name
    else:
        pub_name = "Machine not running - no public DNS name"
        #pub_name = ansi_color.red + pub_name + ansi_color.reset
        
    #logic for private DNS
    if i.state == 'running':
        priv_name = i.private_dns_name
    else:
        priv_name = "Machine not running - no private DNS name"
        #priv_name = ansi_color.red + priv_name + ansi_color.reset
    
    #logic for instance groups
    for group_name in i.groups:
        groups = groups + str(group_name.name)
        if len(i.groups) > 1:
            if count < len(i.groups):
                groups = groups + " AND "
                count = count + 1
            
    info = account_string
    info = info + "," + name    
    info = info + "," + i.id
    info = info + "," + i.instance_type
    info = info + "," + i.placement
    info = info + ',' + i.state
    #info = info + ',' + statusDummy
    #info = info + ',' + alarmDummy
    info = info + ',' + pub_name
    info = info + "," + str(i.ip_address)
    info = info + ',' + priv_name
    info = info + "," + str(i.key_name)
    info = info + "," + str(i.monitored)
    info = info + "," + str(i.launch_time)
    info = info + ',' + groups
    
    #EBS reporting works but painfully slow.....
    for current_volumes in volumes:
    	#print "\t" + str(current_volumes) + "\n"
        if current_volumes.attachment_state() == 'attached':
            filter = {'block-device-mapping.volume-id':current_volumes.id}
            #print "Starting connection for all instances....\n"
            volumesinstance = conn.get_all_instances(filters=filter)
            #print "Volumes by instance: " + str(len(volumesinstance))
            #print "Ending connection for all instances....\n"
            ids = [z for k in volumesinstance for z in k.instances]
            for s in ids:
                if (i.id == s.id):
    		    #print "SUCCESS!!"
                    volume_info = volume_info + str(current_volumes.id) + ',' + str(s.id) + ',' + str(current_volumes.attach_data.device) + ',' + str(current_volumes.size) + ','
            	    info = info + ',' + volume_info
    
    volume_info = ""
    
    return info	

def print_instance(i):
    print instance_info(i)

####main program execution####
regions = sys.argv[1:]
volume_info = ""

if len(regions) == 0:
    regions=['us-east-1']

if len(regions) == 1 and regions[0] == "all":
    working_regions = boto.ec2.regions()
    #print working_regions #DEBUG: uncomment to view all the regions that will be searched for "all"
else:
    working_regions = [ boto.ec2.get_region(x) for x in regions ]

for current_working_region in working_regions:
    print "\n================"
    print current_working_region.name
    print "================"
    print "Account Name,Instance Name,Instance ID,Instance Type,Availability Zone,Instance State,Public DNS,Public IP,Private DNS,Key Name,Monitoring,Launch Time,Security Groups,Attached Volume ID,Attached Volume Instance ID,Mounted Device Name,Attached Volume Size"
    try:
        conn = boto.connect_ec2(region = current_working_region)    	
        #conn = EC2Connection() #same as boto.connect_ec2()
        reservations = conn.get_all_instances()
        volumes = conn.get_all_volumes()
        #print "Volumes array has length of: " + str(len(volumes))
        instances = [i for r in reservations for i in r.instances]
        #pp = pprint.PrettyPrinter(indent=4)
        for r in reservations:
            for i in r.instances:
    	        #pp.pprint(i.__dict__)
                print_instance(i)
                #print_ebs_info(i)
    except boto.exception.EC2ResponseError:
    	print "ERROR -- Could not connect to " + current_working_region.name
    	pass

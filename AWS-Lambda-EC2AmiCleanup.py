import boto3
import collections
import datetime
import time
import sys

ec = boto3.client('ec2', 'us-east-1')
ec2 = boto3.resource('ec2', 'us-east-1')
images = ec2.images.filter(Owners=["self"])

def lambda_handler(event, context):

    reservations = ec.describe_instances(
        Filters=[
            {'Name': 'tag-key', 'Values': ['backup', 'Backup']},
        ]
    ).get(
        'Reservations', []
    )

    instances = sum(
        [
            [i for i in r['Instances']]
            for r in reservations
        ], [])

    print "Found %d instances that need evaluated" % len(instances)

    to_tag = collections.defaultdict(list)

    date = datetime.datetime.now()
    date_fmt = date.strftime('%Y-%m-%d')
    delete_date = None

    imagesList = []

    # Set to true once we confirm we have a backup taken today
    backupSuccess = False

    # Loop through all of our instances with a tag named "Backup"
    for instance in instances:
	
	try:
            instance_name = [
                t.get('Value') for t in instance['Tags']
                if t['Key'] == 'Name'][0]
        except IndexError:
            instance_name = instance['InstanceId']

        # Loop through each image of our current instance
        for image in images:

            # Matches based on the AMIBackup naming convention
            if image.name.startswith('Lambda - ' + instance_name):

                print "FOUND IMAGE " + image.id + " for instance: " + instance_name

                try:
                    if image.tags is not None:
                        deletion_date = [
                            t.get('Value') for t in image.tags
                            if t['Key'] == 'DeleteOn'][0]
                        delete_date = time.strptime(deletion_date, "%m-%d-%Y")
                except IndexError:
                    deletion_date = False
                    delete_date = False

                today_time = datetime.datetime.now().strftime('%m-%d-%Y')
                today_date = time.strptime(today_time, '%m-%d-%Y')

                # If image's DeleteOn date is less than or equal to today,
                # add this image to our list of images to process later
                if delete_date <= today_date:
                    imagesList.append(image.id)

                # Make sure we have an AMI from today and mark backupSuccess as true
                #if image.name.endswith(date_fmt):
                if date_fmt in image.name:
                    # Our latest backup from our other Lambda Function succeeded
                    backupSuccess = True
                    print "Latest backup from " + date_fmt + " was a success"

    if backupSuccess == True:
        
        print "About to process the following AMIs:"
        print imagesList

        myAccount = boto3.client('sts').get_caller_identity()['Account']
        snapshots = ec.describe_snapshots(OwnerIds=[myAccount])['Snapshots']

        # loop through list of image IDs
        for image in imagesList:
            print "Deregistering image " + image
            amiResponse = ec.deregister_image(
                DryRun=False,
                ImageId=image
                #delete_snapshot=True # maybe in the future when AWS upgrades boto
            )
            

            for snapshot in snapshots:
                if snapshot['Description'].find(image) > 0:
                    print "Snapshot found in AMI description"
                    snap = ec.delete_snapshot(SnapshotId=snapshot['SnapshotId'])
                    print "Deleting snapshot " + snapshot['SnapshotId']
                    print "-------------"

    else:
        print "No current backup found. Termination suspended."

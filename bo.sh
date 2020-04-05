#!/bin/bash
# chmod +x bo.sh
# sudo cp bo.sh /usr/local/bin/bo

set -e

help="\
Usage: bo [OPTION]... [FILE]
A simple CLI utility for transacting files over Google Cloud Storage.
Example: bo hello.cpp

OPTIONS:
  -h                        Prints this help message.
  -v                        Print debug messages.
  -b                        Bucket to transact with. Defaults to default_bucket variable in environment.
                            Specify default using \`export default_bucket=BUCKET\` or with this param.
  -f                       The file to transact. Provide multiple files delimited by comma.
"
print_retry()
{
echo "Usage `basename $0` [options ]
Try 'bo --help' for more information."
}

type python3 &> /dev/null || { echo "python3 not installed, exiting.." && exit 1; }

: ${google_access_key_id?"google_access_key_id environment variable not set."}
: ${google_access_key_secret?"google_access_key_secret environment variable not set."}

python3 -c 'import boto3' 2> /dev/null || { while [[ -z ${REPLY} ]]
do
    echo "python library boto3 is missing, install? (y/n)"
    read -n1
    if [[ $REPLY = "y" ]]
    then
        python3 -m pip install boto3 
    elif [[ $REPLY = "n" ]]
    then
        echo "python library boto3 is required for this tool to work."
    else
        echo 'choose between (y/n)'
    fi
done

}

: ${1?"Usage `basename $0` [options ]
Try 'bo --help' for more information."}

VERBOSE=false

while getopts ":hb:f:v" Option
do
    case "$Option" in    
        # *) echo $Option $OPTARG $OPTIND;;
        h) echo "$help"; exit ;;
        f) FILE=$OPTARG;;
        v) VERBOSE=true;;
        b) default_bucket=$OPTARG;;
        *) echo "Unknown flag - $OPTARG"; print_retry; exit;;
    esac
done
echo $OPTIND $#
shift $(($OPTIND - 1))
if (($# == 1))
then
FILE=$1;
elif (($# != 0))
then
echo "Parameter without flags provided"
exit 1
fi

echo FILE $FILE buck $default_bucket optind $OPTIND 

echo args $#


: ${default_bucket?"Neither default bucket set or specified
$(print_retry)"}

if [[ ! -f ${FILE} ]]
    then
    echo "$FILE is not a valid file.";
    exit
fi

BUCKET=${2:-$default_bucket}

# ugly, will be removed later.
python3 -c "
import os
import boto3
import botocore
def transact_file_gcp(file_name, bucket):
    client = boto3.client(
            's3',
            region_name='auto',
            endpoint_url='https://storage.googleapis.com',
            aws_access_key_id=os.environ['google_access_key_id'],
            aws_secret_access_key=os.environ['google_access_key_secret'],
        )
    # download
    if file_name.startswith('gcp://'):
        bucket, remote_file_name = file_name.split('/')[-2:]
        file_name = remote_file_name
        i = 0
        while os.path.exists(file_name):
            i += 1
            file_name = '.'.join(remote_file_name.split('.')[:-1]) + '(' + str(i) +').' + remote_file_name.split('.')[-1]
        try:
            client.head_object(Bucket=bucket, Key=remote_file_name)
            client.download_file(bucket, remote_file_name, file_name)
            return 'File download:' + file_name
        except botocore.exceptions.ClientError as e:
            return('Errored with status code ' + str(e.response['Error']['Code']))
            
    # upload
    else:
        client.upload_file(file_name, bucket, file_name)    
        return 'gcp://' + bucket + '/' + file_name

files = \"$FILE\"
for file in files.split(','):
    if \"$VERBOSE\" == \"true\":
        print(\"transacting file \" + file + \"...\")
    print(transact_file_gcp(file, \"$BUCKET\"))
"

#!/bin/bash
# pip install boto3
# chmod +x bo.sh
# multiple file upload/download
set -e

help="\
Usage: bo [OPTION]... [FILE]
A simple CLI utility for transacting files over Google Cloud Storage.
Example: bo hello.cpp

OPTIONS:
  -h, --help                Prints this help message.
  -v, --verbose             Print debug messages.
  -b, --bucket              Bucket to transact with. Defaults to default_bucket variable in environment.
                            Specify default using \`export default_bucket=BUCKET\` or with this param.
  -f, --file                The file to transact. Provide multiple files delimited by comma.
"

SHORT=hbfv:
LONG=help,bucket:,file:,verbose,links_file:

if [[ -z $1 ]]; then
    echo "Usage $0 [options ]"
    echo "Try 'bo --help' for more information."
    exit
fi

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
eval set -- "$OPTS"
VERBOSE=false
while [ -n "$1" ]
do
    case "$1" in    
        -h | --help) echo "$help"; exit ;;
        -f | --file) FILE=$2; shift 2;;
        -v | --verbose) VERBOSE=true; shift ;; 
        --bucket) default_bucket=$2; shift 2;;
        --) shift  ;;
        *) echo "Unknown param - " $1 "type $0 --help for usage instructions"; break;;
    esac
done

type python3 &> /dev/null || { echo "python3 not installed, exiting.." && exit 1; }

if [[ -z ${google_access_key_id+x} ]]
then
    echo "google_access_key_id environment variable not set."
    exit 1
fi

if [[ -z ${google_access_key_secret+x} ]]
then
    echo "google_access_key_secret environment variable not set."
    exit
fi

python -c 'import boto3' 2> /dev/null || { while [[ -z ${response} ]]
do
    echo "python library boto3 is missing, install? (y/n)"
    read response
    if [[ $response = "y" ]]
    then
        python3 -m pip install boto3 
    elif [[ $response = "n" ]]
    then
        echo "python library boto3 is required for this tool to work."
    else
        echo 'choose between (y/n)'
    fi
done

}


if [[ -z ${default_bucket+x} ]]
    then
    echo "Neither default bucket set or specified, call Usage $0 --help";
    exit
fi

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

#!/bin/bash

set -e

echo 'AWS ECR dockercfg generator'

: "${AWS_REGION:?Need to set AWS_REGION}"
: "${AWS_ACCESS_KEY_ID:?Need to set AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?Need to set AWS_SECRET_ACCESS_KEY}"

cat << EOF > ~/.aws/config
[default]
region = $AWS_REGION
EOF

# For multi account aws setups, use primary credentials to assume the role in
# the target account
if [[ -n $AWS_STS_ROLE || -n $AWS_STS_ACCOUNT ]]; then
  : "${AWS_STS_ROLE:?Need to set AWS_STS_ROLE}"
  : "${AWS_STS_ACCOUNT:?Need to set AWS_STS_ACCOUNT}"

  role="arn:aws:iam::${AWS_STS_ACCOUNT}:role/${AWS_STS_ROLE}"
  echo "Using STS to get credentials for ${role}"

  aws_tmp=$(mktemp -t aws-json-XXXXXX)

  aws sts assume-role --role-arn "${role}" --role-session-name aws_docker_creds > "${aws_tmp}"

  export AWS_ACCESS_KEY_ID=$(cat ${aws_tmp} | jq -r ".Credentials.AccessKeyId")
  export AWS_SECRET_ACCESS_KEY=$(cat ${aws_tmp} | jq -r ".Credentials.SecretAccessKey")
  export AWS_SESSION_TOKEN=$(cat ${aws_tmp} | jq -r ".Credentials.SessionToken")
  export AWS_SESSION_EXPIRATION=$(cat ${aws_tmp} | jq -r ".Credentials.Expiration")
fi

# fetching aws docker login
if [ -f /opt/docker/config.json ]; then
    echo "Setting previous AWS ECR login"
    mkdir -p ~/.docker
    cp /opt/docker/config.json ~/.docker/config.json
else
    echo "Logging into AWS ECR"
    $(aws ecr get-login)
    cp ~/.docker/config.json /opt/docker/config.json
fi

# writing aws docker creds to desired path
echo "Writing Docker creds to $1"
chmod 544 ~/.docker/config.json
cp ~/.docker/config.json $1

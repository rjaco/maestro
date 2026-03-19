---
name: service-cloud
description: "Cloud provider operations for AWS, Vercel, DigitalOcean, and Cloudflare. Provisions and manages infrastructure via CLI tools (aws, vercel, doctl, wrangler). Required env vars: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY + AWS_DEFAULT_REGION, VERCEL_TOKEN, DIGITALOCEAN_ACCESS_TOKEN, CF_TOKEN. All actions classified by autonomy tier."
---

# Cloud Provider Operations

Provision and manage cloud infrastructure across AWS, Vercel, DigitalOcean, and Cloudflare. Uses CLI tools — never the browser. All secrets come from the credential manager; never hardcode keys.

## Autonomy Classification

| Tier | Label | Meaning |
|------|-------|---------|
| T1 | Free | Read-only. No cost, no side effects. Run without asking. |
| T2 | Reversible-paid | Creates resources. Incurs cost. Can be deleted. Ask once per session. |
| T3 | Irreversible | Destroys resources or data. Cannot be undone. Always confirm. |

---

## AWS

### Required Setup

```bash
# Required env vars (set via credential manager)
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1   # or your region

# Verify CLI is installed
aws --version

# Install (if missing)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

### Identity & Account (T1)

```bash
# Verify identity and active account
aws sts get-caller-identity

# List all S3 buckets
aws s3 ls

# List EC2 instances (all states)
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' --output table

# List Route53 hosted zones
aws route53 list-hosted-zones --query 'HostedZones[].[Name,Id]' --output table

# List Lambda functions
aws lambda list-functions --query 'Functions[].[FunctionName,Runtime,LastModified]' --output table

# Describe a specific EC2 instance
aws ec2 describe-instances --instance-ids i-0123456789abcdef0
```

### Compute & Storage — Create (T2)

```bash
# Launch an EC2 instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.micro \
  --key-name my-keypair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=my-server}]'

# Create an S3 bucket
aws s3 mb s3://my-unique-bucket-name --region us-east-1

# Upload a file to S3
aws s3 cp /local/path/file.txt s3://my-bucket/remote/path/

# Sync a directory to S3 (for static sites)
aws s3 sync ./dist s3://my-bucket/ --delete

# Add a DNS A record via Route53
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "1.2.3.4"}]
      }
    }]
  }'

# Create a Lambda function
aws lambda create-function \
  --function-name my-function \
  --runtime nodejs20.x \
  --role arn:aws:iam::123456789012:role/lambda-role \
  --handler index.handler \
  --zip-file fileb://function.zip
```

### Compute & Storage — Delete (T3)

```bash
# Terminate EC2 instance (IRREVERSIBLE — data on instance store lost)
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0

# Delete S3 bucket and all contents (IRREVERSIBLE)
aws s3 rb s3://my-bucket-name --force

# Delete a Route53 hosted zone (IRREVERSIBLE — all DNS records lost)
aws route53 delete-hosted-zone --id /hostedzone/Z1234567890ABC

# Delete Lambda function (IRREVERSIBLE)
aws lambda delete-function --function-name my-function
```

### Common Workflows

**Deploy a static site to S3 + CloudFront:**
```bash
# 1. Create bucket
aws s3 mb s3://my-site-bucket --region us-east-1

# 2. Enable static website hosting
aws s3 website s3://my-site-bucket/ --index-document index.html --error-document 404.html

# 3. Sync build output
aws s3 sync ./dist s3://my-site-bucket/ --delete --acl public-read

# 4. Verify
aws s3 ls s3://my-site-bucket/
```

**Launch an EC2 instance and get its IP:**
```bash
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.micro \
  --key-name my-keypair \
  --query 'Instances[0].InstanceId' \
  --output text)

aws ec2 wait instance-running --instance-ids $INSTANCE_ID

aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

### Error Handling

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `NoCredentialProviders` | Missing env vars | Check AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set |
| `InvalidClientTokenId` | Wrong credentials | Verify keys in credential manager are correct and active |
| `UnauthorizedOperation` | Missing IAM permissions | Check the IAM role/user has the required policy |
| `BucketAlreadyOwnedByYou` | Bucket exists | Use existing bucket or pick a different name |
| `InstanceLimitExceeded` | Account limit | Request limit increase or use a different region |
| `InvalidAMIID.NotFound` | AMI not in region | Use `aws ec2 describe-images` to find a valid AMI |

---

## Vercel

### Required Setup

```bash
# Required env var
export VERCEL_TOKEN=$VERCEL_TOKEN   # from credential manager

# Install CLI (if missing)
npm install -g vercel

# Or use npx
npx vercel --version

# Authenticate (interactive — only needed once per machine)
vercel login
```

### Inspect & List (T1)

```bash
# Verify authentication
vercel whoami

# List all deployments for current project
vercel ls

# List deployments for a specific project
vercel ls my-project-name

# Inspect a specific deployment
vercel inspect https://my-app-abc123.vercel.app

# List all domains
vercel domains ls

# List environment variables (names only, values masked)
vercel env ls
```

### Deploy & Configure (T2)

```bash
# Deploy current directory (production)
vercel --prod

# Deploy for preview (creates a unique URL)
vercel deploy

# Add an environment variable
vercel env add DATABASE_URL production

# Add same env var to all environments
vercel env add DATABASE_URL production
vercel env add DATABASE_URL preview
vercel env add DATABASE_URL development

# Add a custom domain
vercel domains add example.com

# Link a domain to a project
vercel alias set https://my-app-abc123.vercel.app example.com
```

### Remove (T3)

```bash
# Remove a specific deployment (IRREVERSIBLE)
vercel rm https://my-app-abc123.vercel.app

# Remove all deployments for a project (IRREVERSIBLE)
vercel rm my-project-name --safe

# Remove a domain (IRREVERSIBLE)
vercel domains rm example.com
```

### Common Workflows

**Deploy a Next.js app:**
```bash
# 1. Verify auth
vercel whoami

# 2. Deploy to preview first
vercel deploy

# 3. Review preview URL, then promote to production
vercel --prod
```

**Set environment variables from a file:**
```bash
# For each line in .env.production (never commit this file)
while IFS= read -r line; do
  KEY="${line%%=*}"
  VAL="${line#*=}"
  echo "$VAL" | vercel env add "$KEY" production
done < .env.production
```

### Error Handling

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `Not authenticated` | Token missing or expired | Set VERCEL_TOKEN or run `vercel login` |
| `Project not linked` | Running outside project dir | Run `vercel link` to associate directory |
| `Domain already in use` | Domain assigned elsewhere | Remove from other project first |
| Build failure | Build command failed | Check `vercel logs` for the specific error |
| `Rate limit exceeded` | Too many deploys | Wait and retry; check plan limits |

---

## DigitalOcean

### Required Setup

```bash
# Required env var
export DIGITALOCEAN_ACCESS_TOKEN=$DIGITALOCEAN_ACCESS_TOKEN   # from credential manager

# Install CLI (if missing)
# Linux:
wget https://github.com/digitalocean/doctl/releases/download/v1.101.0/doctl-1.101.0-linux-amd64.tar.gz
tar xf doctl-1.101.0-linux-amd64.tar.gz && sudo mv doctl /usr/local/bin

# Authenticate
doctl auth init --access-token $DIGITALOCEAN_ACCESS_TOKEN
```

### Inspect & List (T1)

```bash
# Verify account and billing
doctl account get

# List all droplets
doctl compute droplet list --format ID,Name,Status,PublicIPv4,Region,Size

# List all apps
doctl apps list

# List databases
doctl databases list

# Get app details
doctl apps get <app-id>

# List Kubernetes clusters
doctl kubernetes cluster list
```

### Create (T2)

```bash
# Create a droplet
doctl compute droplet create my-server \
  --image ubuntu-22-04-x64 \
  --size s-1vcpu-1gb \
  --region nyc3 \
  --ssh-keys $(doctl compute ssh-key list --no-header --format ID | head -1)

# Create an App Platform app from a spec file
doctl apps create --spec app.yaml

# Create a managed database (PostgreSQL)
doctl databases create my-db \
  --engine pg \
  --version 15 \
  --region nyc3 \
  --size db-s-1vcpu-1gb \
  --num-nodes 1
```

**App spec file (`app.yaml`) example:**
```yaml
name: my-app
region: nyc
services:
  - name: web
    github:
      repo: my-org/my-repo
      branch: main
      deploy_on_push: true
    run_command: npm start
    http_port: 3000
    envs:
      - key: DATABASE_URL
        value: "${db.DATABASE_URL}"
```

### Delete (T3)

```bash
# Delete a droplet (IRREVERSIBLE — all data lost)
doctl compute droplet delete <droplet-id> --force

# Delete an app (IRREVERSIBLE)
doctl apps delete <app-id> --force

# Delete a database (IRREVERSIBLE — all data lost)
doctl databases delete <database-id> --force
```

### Common Workflows

**Deploy an app and get its live URL:**
```bash
# 1. Create app from spec
APP_ID=$(doctl apps create --spec app.yaml --no-wait --format ID --no-header)

# 2. Wait for deployment
doctl apps get $APP_ID --format LiveURL,ActiveDeployment.Phase

# 3. Get live URL
doctl apps get $APP_ID --format LiveURL --no-header
```

### Error Handling

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `unable to initialize DigitalOcean API client` | Missing token | Set DIGITALOCEAN_ACCESS_TOKEN |
| `422 Unprocessable Entity` | Invalid spec or name conflict | Check spec file, use unique names |
| `droplet limit reached` | Account limit | Request increase or delete unused droplets |
| `SSH key not found` | No key in account | Add SSH key via `doctl compute ssh-key import` |

---

## Cloudflare

### Required Setup

```bash
# Required env vars
export CF_TOKEN=$CLOUDFLARE_API_TOKEN   # from credential manager
export CF_ACCOUNT_ID=$CLOUDFLARE_ACCOUNT_ID

# Install Wrangler (Workers CLI)
npm install -g wrangler

# Authenticate Wrangler
wrangler login
# Or use token directly
export CLOUDFLARE_API_TOKEN=$CF_TOKEN
```

### Inspect & List (T1)

```bash
# Verify Wrangler authentication
wrangler whoami

# List all Workers
wrangler deployments list

# List zones (domains) via API
curl -s -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones" \
  | jq '.result[] | {name, id, status}'

# List DNS records for a zone
curl -s -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  | jq '.result[] | {type, name, content, proxied}'

# List R2 buckets
wrangler r2 bucket list

# List KV namespaces
wrangler kv:namespace list
```

### Deploy & Configure (T2)

```bash
# Deploy a Cloudflare Worker
wrangler deploy

# Create an R2 bucket
wrangler r2 bucket create my-bucket

# Create a KV namespace
wrangler kv:namespace create MY_KV

# Add a DNS A record via API
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "A",
    "name": "@",
    "content": "1.2.3.4",
    "ttl": 1,
    "proxied": true
  }'

# Add a CNAME record
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CNAME",
    "name": "www",
    "content": "my-app.example.com",
    "ttl": 1,
    "proxied": true
  }'
```

### Delete (T3)

```bash
# Delete a Worker (IRREVERSIBLE)
wrangler delete

# Delete an R2 bucket (IRREVERSIBLE — all objects lost)
wrangler r2 bucket delete my-bucket

# Delete a DNS record via API (IRREVERSIBLE)
# First get the record ID:
RECORD_ID=$(curl -s -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=app.example.com" \
  | jq -r '.result[0].id')

# Then delete it:
curl -s -X DELETE \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_TOKEN"
```

### Common Workflows

**Deploy a static site via Workers + R2:**
```bash
# 1. Create R2 bucket
wrangler r2 bucket create my-site

# 2. Upload assets
wrangler r2 object put my-site/index.html --file ./dist/index.html

# 3. Deploy Worker to serve assets
wrangler deploy

# 4. Verify
wrangler deployments list
```

### Error Handling

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `Authentication error` | Invalid or missing CF_TOKEN | Verify token has correct permissions (Zone:Edit, Workers:Edit) |
| `10000: Authentication error` | Token scoped to wrong account | Check CF_ACCOUNT_ID matches token |
| `Zone not found` | Wrong ZONE_ID | Use the zones API list to get correct ID |
| `You have reached your script limit` | Free plan Workers limit | Upgrade plan or delete unused Workers |
| `wrangler: command not found` | CLI not installed | `npm install -g wrangler` |

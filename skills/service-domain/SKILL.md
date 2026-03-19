---
name: service-domain
description: "Domain registration and DNS management via Cloudflare (API) and Namecheap (API). Covers A, AAAA, CNAME, MX, TXT, NS records plus SSL/TLS setup. Required env vars: CLOUDFLARE_API_TOKEN + CLOUDFLARE_ZONE_ID for Cloudflare; NC_USER + NC_KEY + NC_IP for Namecheap. All actions classified by autonomy tier."
---

# Domain & DNS Operations

Search, register, and manage domains. Configure DNS records across providers. All API calls use env vars from the credential manager — never hardcode tokens or keys.

## Autonomy Classification

| Tier | Label | Meaning |
|------|-------|---------|
| T1 | Free | Read-only. No cost, no side effects. Run without asking. |
| T2 | Reversible-paid | Creates or modifies records. Small cost impact. Ask once per session. |
| T3 | Irreversible | Domain purchase (billing committed), record deletion. Always confirm. |

---

## Cloudflare DNS

Cloudflare is the preferred DNS provider — fast propagation, free plan, and a clean API.

### Required Setup

```bash
# Required env vars (set via credential manager)
export CLOUDFLARE_API_TOKEN=$CLOUDFLARE_API_TOKEN
export CLOUDFLARE_ZONE_ID=$CLOUDFLARE_ZONE_ID      # per-domain zone ID

# Find your Zone ID:
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones" \
  | jq '.result[] | {name, id}'
# Copy the id value for your domain → set as CLOUDFLARE_ZONE_ID

# Verify token works
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  | jq '.result.status'
# Should return "active"
```

### Inspect (T1)

```bash
# List all zones (domains) in the account
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones" \
  | jq '.result[] | {name, id, status, nameservers: .name_servers}'

# List all DNS records for a zone
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  | jq '.result[] | {id, type, name, content, proxied, ttl}'

# Filter records by type
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=A" \
  | jq '.result[] | {name, content}'

# Check zone status and nameservers
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID" \
  | jq '{status: .result.status, nameservers: .result.name_servers}'
```

### Add or Update Records (T2)

All record additions are idempotent if you use the correct zone ID. Use `"proxied": true` for HTTP traffic (enables Cloudflare CDN/DDoS protection); use `false` for non-HTTP records like MX and TXT.

**A record (domain → IPv4):**
```bash
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "A",
    "name": "@",
    "content": "1.2.3.4",
    "ttl": 1,
    "proxied": true
  }'
```

**AAAA record (domain → IPv6):**
```bash
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "AAAA",
    "name": "@",
    "content": "2001:db8::1",
    "ttl": 1,
    "proxied": true
  }'
```

**CNAME record (subdomain → another domain):**
```bash
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CNAME",
    "name": "www",
    "content": "myapp.vercel.app",
    "ttl": 1,
    "proxied": true
  }'
```

**MX record (email routing):**
```bash
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MX",
    "name": "@",
    "content": "mail.example.com",
    "priority": 10,
    "ttl": 3600,
    "proxied": false
  }'
```

**TXT record (domain verification, SPF, DKIM):**
```bash
# SPF record
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "TXT",
    "name": "@",
    "content": "v=spf1 include:sendgrid.net ~all",
    "ttl": 3600,
    "proxied": false
  }'

# Domain verification (e.g., Google Search Console)
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "TXT",
    "name": "@",
    "content": "google-site-verification=abc123",
    "ttl": 3600,
    "proxied": false
  }'
```

**NS record (delegate subdomain to another nameserver):**
```bash
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "NS",
    "name": "sub",
    "content": "ns1.other-provider.com",
    "ttl": 3600,
    "proxied": false
  }'
```

**Update an existing record:**
```bash
# 1. Get the record ID
RECORD_ID=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=app.example.com&type=A" \
  | jq -r '.result[0].id')

# 2. Update it
curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "A",
    "name": "app",
    "content": "5.6.7.8",
    "ttl": 1,
    "proxied": true
  }'
```

### Delete Records (T3)

```bash
# 1. Find the record ID (T1)
RECORD_ID=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=old.example.com" \
  | jq -r '.result[0].id')

# 2. Delete it (IRREVERSIBLE — confirm before running)
curl -s -X DELETE \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  | jq '{success: .success, id: .result.id}'
```

---

## Namecheap

Used for domain registration and renewal. DNS management is handled in Cloudflare after purchase.

### Required Setup

```bash
# Required env vars (set via credential manager)
export NC_USER=$NAMECHEAP_USER          # Namecheap account username
export NC_KEY=$NAMECHEAP_API_KEY        # API key from Profile > Tools > API Access
export NC_IP=$NAMECHEAP_WHITELISTED_IP  # Your server's public IP (must be whitelisted in Namecheap account)

# Get your public IP if unknown
curl -s https://api.ipify.org

# Namecheap requires whitelisting the calling IP in:
# Profile > Tools > API Access > Whitelisted IPs
```

### Search & Inspect (T1)

```bash
# Check domain availability
curl -s "https://api.namecheap.com/xml.response?ApiUser=$NC_USER&ApiKey=$NC_KEY&UserName=$NC_USER&Command=namecheap.domains.check&DomainList=myapp.com,myapp.io,myapp.dev&ClientIp=$NC_IP" \
  | grep -oP '(?<=Domain=")[^"]+(?="[^>]*(Available="true"|Available="false"))'

# List registered domains
curl -s "https://api.namecheap.com/xml.response?ApiUser=$NC_USER&ApiKey=$NC_KEY&UserName=$NC_USER&Command=namecheap.domains.getList&ClientIp=$NC_IP" \
  | grep -oP 'Name="[^"]+"'

# Get domain info
curl -s "https://api.namecheap.com/xml.response?ApiUser=$NC_USER&ApiKey=$NC_KEY&UserName=$NC_USER&Command=namecheap.domains.getInfo&DomainName=myapp.com&ClientIp=$NC_IP"
```

### Purchase Domain (T3)

Domain purchase is IRREVERSIBLE — billing is committed immediately and refunds are not guaranteed.

```bash
# Purchase a domain for 1 year (IRREVERSIBLE — confirm with user first)
curl -s "https://api.namecheap.com/xml.response?\
ApiUser=$NC_USER&ApiKey=$NC_KEY&UserName=$NC_USER&\
Command=namecheap.domains.create&\
DomainName=myapp.com&\
Years=1&\
ClientIp=$NC_IP&\
RegistrantFirstName=John&RegistrantLastName=Doe&\
RegistrantAddress1=123+Main+St&RegistrantCity=Anytown&\
RegistrantStateProvince=CA&RegistrantPostalCode=12345&\
RegistrantCountry=US&RegistrantPhone=%2B1.5555555555&\
RegistrantEmailAddress=admin%40myapp.com"
```

After purchase, point Namecheap nameservers to Cloudflare:

```bash
# Set custom nameservers (T2)
curl -s "https://api.namecheap.com/xml.response?\
ApiUser=$NC_USER&ApiKey=$NC_KEY&UserName=$NC_USER&\
Command=namecheap.domains.dns.setCustom&\
SLD=myapp&TLD=com&\
Nameservers=ns1.cloudflare.com,ns2.cloudflare.com&\
ClientIp=$NC_IP"
```

---

## SSL/TLS Certificates

### Cloudflare (Automatic — T1 to configure)

Cloudflare provides free SSL for all proxied domains. No certificate management needed if using Cloudflare proxy (`"proxied": true`).

```bash
# Check SSL mode
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/ssl" \
  | jq '.result.value'
# Returns: "off" | "flexible" | "full" | "strict"

# Set SSL to Full (Strict) — recommended
curl -s -X PATCH \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/ssl" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "strict"}'
```

### Let's Encrypt via certbot (for non-Cloudflare servers)

```bash
# Install certbot
sudo apt-get install certbot

# Issue certificate (domain must resolve to this server)
sudo certbot certonly --standalone -d example.com -d www.example.com \
  --non-interactive --agree-tos --email admin@example.com

# Auto-renew (add to cron)
echo "0 12 * * * root certbot renew --quiet" | sudo tee /etc/cron.d/certbot

# Check certificate expiry
sudo certbot certificates
```

---

## Standard Workflows

### Buy a domain and point it to a server

```bash
# 1. Check availability (T1)
curl -s "https://api.namecheap.com/xml.response?ApiUser=$NC_USER&ApiKey=$NC_KEY&UserName=$NC_USER&Command=namecheap.domains.check&DomainList=myapp.com&ClientIp=$NC_IP"

# 2. Purchase domain (T3 — confirm with user)
# [run namecheap.domains.create command above]

# 3. Set Cloudflare nameservers on Namecheap (T2)
# [run namecheap.domains.dns.setCustom command above]

# 4. Wait for nameserver propagation (up to 24h, usually 30min)
# Check: https://dnschecker.org

# 5. Add A record in Cloudflare (T2)
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"A","name":"@","content":"SERVER_IP","ttl":1,"proxied":true}'

# 6. Add www CNAME (T2)
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"CNAME","name":"www","content":"myapp.com","ttl":1,"proxied":true}'

# 7. Verify DNS resolves correctly (T1)
dig +short myapp.com A
curl -s https://myapp.com -o /dev/null -w "%{http_code}"
```

### Add email sending records (SendGrid)

```bash
# SPF — authorize SendGrid to send from your domain
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"TXT","name":"@","content":"v=spf1 include:sendgrid.net ~all","ttl":3600,"proxied":false}'

# DKIM — SendGrid provides these values in their dashboard
# Replace DKIM_KEY with the value from SendGrid > Settings > Sender Authentication
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"CNAME","name":"em1234","content":"em1234.myapp.com.dkim.sendgrid.net","ttl":3600,"proxied":false}'
```

---

## DNS Record Reference

| Type | Use Case | Proxied? | Notes |
|------|----------|----------|-------|
| A | Domain → IPv4 | Yes (HTTP) / No (other) | Root `@` and subdomains |
| AAAA | Domain → IPv6 | Yes (HTTP) / No (other) | Same pattern as A |
| CNAME | Subdomain → hostname | Yes (HTTP) | Cannot use on root `@` |
| MX | Email routing | No | Priority 10 = primary |
| TXT | SPF, DKIM, verification | No | Multiple TXT records allowed |
| NS | Delegate subdomain DNS | No | Points to another nameserver |

## Error Handling

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `9103: Invalid API Key` (Cloudflare) | Wrong or expired token | Regenerate token at dash.cloudflare.com/profile/api-tokens |
| `Zone not found` | Wrong ZONE_ID | Re-list zones and copy the correct ID |
| `Record already exists` | Duplicate record | List records first, update instead of create |
| `Invalid IP address` (Namecheap) | Calling IP not whitelisted | Add current IP to Namecheap API whitelist |
| `2011166: Parameter Nameservers is Missing` | Malformed Namecheap request | Verify all required query params are present |
| DNS not propagating | TTL caching or nameserver delay | Wait up to 48h; use dnschecker.org to monitor |
| `SSL handshake failed` | Cert not yet issued | Wait 1-2 minutes after enabling Cloudflare proxy |

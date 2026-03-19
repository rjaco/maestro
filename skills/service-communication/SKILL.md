---
name: service-communication
description: "Email and SMS messaging via SendGrid (email API) and Twilio (SMS/voice API). Required env vars: SENDGRID_API_KEY for email; TWILIO_SID + TWILIO_TOKEN + TWILIO_FROM for SMS. Sending messages is irreversible. All actions classified by autonomy tier."
---

# Email & SMS Communication

Send transactional email and SMS messages via SendGrid and Twilio. All secrets come from the credential manager. Sending a message is irreversible — confirm recipient and content before dispatching.

## Autonomy Classification

| Tier | Label | Meaning |
|------|-------|---------|
| T1 | Free | Read-only. Lists templates, phone numbers, account info. No cost. |
| T2 | Reversible-paid | Creates templates, sender identities, or configuration. Cost-bearing if resource-based. |
| T3 | Irreversible | Sends a message. Cannot be recalled. Real cost per message. Always confirm. |

---

## SendGrid (Email)

### Required Setup

```bash
# Required env var (set via credential manager)
export SENDGRID_API_KEY=$SENDGRID_API_KEY

# Verify the key works
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  "https://api.sendgrid.com/v3/user/profile"
# Should return 200
```

### Inspect (T1)

```bash
# List dynamic email templates
curl -s -H "Authorization: Bearer $SENDGRID_API_KEY" \
  "https://api.sendgrid.com/v3/templates?generations=dynamic" \
  | jq '.templates[] | {id, name, updated_at}'

# Get a specific template with its active version
curl -s -H "Authorization: Bearer $SENDGRID_API_KEY" \
  "https://api.sendgrid.com/v3/templates/d-abc123" \
  | jq '{name: .name, active_version: .versions[] | select(.active == 1) | {id, subject}}'

# List verified sender identities
curl -s -H "Authorization: Bearer $SENDGRID_API_KEY" \
  "https://api.sendgrid.com/v3/verified_senders" \
  | jq '.results[] | {from_email, from_name, verified}'

# Get account stats
curl -s -H "Authorization: Bearer $SENDGRID_API_KEY" \
  "https://api.sendgrid.com/v3/user/credits" \
  | jq .

# Check suppression list (bounces, unsubscribes)
curl -s -H "Authorization: Bearer $SENDGRID_API_KEY" \
  "https://api.sendgrid.com/v3/suppression/bounces?limit=10" \
  | jq '.[] | {email, reason, created}'
```

### Create Templates (T2)

```bash
# Create a dynamic template
curl -s -X POST \
  "https://api.sendgrid.com/v3/templates" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Welcome Email",
    "generation": "dynamic"
  }' | jq '{id: .id, name: .name}'

# Add a version to the template (with HTML body)
TEMPLATE_ID=d-abc123
curl -s -X POST \
  "https://api.sendgrid.com/v3/templates/$TEMPLATE_ID/versions" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "'"$TEMPLATE_ID"'",
    "name": "v1",
    "subject": "Welcome to {{app_name}}, {{first_name}}!",
    "html_content": "<h1>Welcome, {{first_name}}!</h1><p>Thanks for signing up for {{app_name}}.</p>",
    "plain_content": "Welcome, {{first_name}}! Thanks for signing up for {{app_name}}.",
    "active": 1
  }'
```

### Send Email (T3)

Sending is irreversible. Verify `to` email and `subject` before executing.

**Plain text email:**
```bash
curl -s -X POST "https://api.sendgrid.com/v3/mail/send" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "personalizations": [
      {
        "to": [{"email": "user@example.com", "name": "Jane Doe"}]
      }
    ],
    "from": {"email": "noreply@myapp.com", "name": "My App"},
    "subject": "Your account is ready",
    "content": [
      {"type": "text/plain", "value": "Hi Jane, your account is ready. Log in at https://myapp.com"},
      {"type": "text/html", "value": "<p>Hi Jane, your account is ready. <a href=\"https://myapp.com\">Log in</a></p>"}
    ]
  }'
```

**Dynamic template email:**
```bash
curl -s -X POST "https://api.sendgrid.com/v3/mail/send" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "personalizations": [
      {
        "to": [{"email": "user@example.com"}],
        "dynamic_template_data": {
          "first_name": "Jane",
          "app_name": "My App",
          "confirm_url": "https://myapp.com/confirm?token=abc123"
        }
      }
    ],
    "from": {"email": "noreply@myapp.com", "name": "My App"},
    "template_id": "d-abc123def456"
  }'
```

**Batch email (multiple recipients, individual data):**
```bash
curl -s -X POST "https://api.sendgrid.com/v3/mail/send" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "personalizations": [
      {
        "to": [{"email": "alice@example.com"}],
        "dynamic_template_data": {"first_name": "Alice"}
      },
      {
        "to": [{"email": "bob@example.com"}],
        "dynamic_template_data": {"first_name": "Bob"}
      }
    ],
    "from": {"email": "noreply@myapp.com"},
    "template_id": "d-abc123def456"
  }'
```

**Email with attachment:**
```bash
# Encode file to base64
ATTACHMENT=$(base64 -w 0 /path/to/report.pdf)

curl -s -X POST "https://api.sendgrid.com/v3/mail/send" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "personalizations": [{"to": [{"email": "user@example.com"}]}],
    "from": {"email": "noreply@myapp.com"},
    "subject": "Your monthly report",
    "content": [{"type": "text/plain", "value": "Please find your report attached."}],
    "attachments": [
      {
        "content": "'"$ATTACHMENT"'",
        "type": "application/pdf",
        "filename": "report.pdf"
      }
    ]
  }'
```

### Common Workflows

**Send a transactional email and verify delivery:**
```bash
# 1. Check sender is verified (T1)
curl -s -H "Authorization: Bearer $SENDGRID_API_KEY" \
  "https://api.sendgrid.com/v3/verified_senders" \
  | jq '.results[] | select(.from_email == "noreply@myapp.com") | .verified'

# 2. Send (T3 — confirm recipient before running)
curl -s -X POST "https://api.sendgrid.com/v3/mail/send" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "personalizations": [{"to": [{"email": "user@example.com"}]}],
    "from": {"email": "noreply@myapp.com"},
    "subject": "Hello from Maestro",
    "content": [{"type": "text/plain", "value": "This is a test message."}]
  }'
# HTTP 202 = accepted for delivery

# 3. Check if recipient bounced (T1)
curl -s -H "Authorization: Bearer $SENDGRID_API_KEY" \
  "https://api.sendgrid.com/v3/suppression/bounces/user@example.com" \
  | jq .
```

### Error Handling

| Error | HTTP | Likely Cause | Fix |
|-------|------|-------------|-----|
| `Unauthorized` | 401 | Wrong or expired API key | Regenerate key in SendGrid dashboard |
| `Forbidden` | 403 | Sender not verified | Verify sender at app.sendgrid.com/settings/sender_auth |
| `The from address does not match a verified sender` | 403 | from email not in verified senders | Add and verify the from address |
| `Bad Request` | 400 | Missing required field | Check personalizations, from, subject, and content |
| `Template not found` | 400 | Wrong template_id | List templates to get valid IDs |
| No response / timeout | — | Network issue | Retry with exponential backoff |

---

## Twilio (SMS)

### Required Setup

```bash
# Required env vars (set via credential manager)
export TWILIO_SID=$TWILIO_ACCOUNT_SID     # starts with AC...
export TWILIO_TOKEN=$TWILIO_AUTH_TOKEN
export TWILIO_FROM=$TWILIO_PHONE_NUMBER   # E.164 format: +15551234567

# Verify credentials
curl -s "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  | jq '{status: .status, friendly_name: .friendly_name}'
```

### Inspect (T1)

```bash
# List purchased phone numbers
curl -s \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/IncomingPhoneNumbers.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  | jq '.incoming_phone_numbers[] | {phone_number, friendly_name, capabilities}'

# List sent messages (last 20)
curl -s \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Messages.json?PageSize=20" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  | jq '.messages[] | {sid, to, from, status, date_sent, error_message}'

# Get a specific message status
curl -s \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Messages/SM123abc.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  | jq '{status, error_code, error_message}'

# Check account balance
curl -s \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Balance.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  | jq .

# Search available phone numbers to purchase
curl -s \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/AvailablePhoneNumbers/US/Local.json?AreaCode=415" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  | jq '.available_phone_numbers[:5] | .[] | {phone_number, locality, region}'
```

### Purchase Phone Number (T2)

```bash
# Purchase a phone number
curl -s -X POST \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/IncomingPhoneNumbers.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  -d "PhoneNumber=%2B14155551234" \
  | jq '{sid, phone_number, status}'
```

### Send SMS (T3)

Sending an SMS is irreversible and incurs cost per message. Confirm the `To` number and message body before executing.

**Send a plain SMS:**
```bash
curl -s -X POST \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Messages.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  -d "To=%2B1234567890" \
  -d "From=$TWILIO_FROM" \
  -d "Body=Hello from Maestro! Your verification code is 123456." \
  | jq '{sid, status, error_code, error_message}'
# status "queued" = accepted; check again for "sent" or "delivered"
```

**Send SMS using URL encoding for special characters:**
```bash
MESSAGE="Your order #1042 has shipped. Track it at: https://myapp.com/track/1042"
ENCODED_MESSAGE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MESSAGE'))")

curl -s -X POST \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Messages.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  -d "To=%2B1234567890" \
  -d "From=$TWILIO_FROM" \
  --data-urlencode "Body=$MESSAGE" \
  | jq '{sid, status}'
```

**Send MMS (with media):**
```bash
curl -s -X POST \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Messages.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  -d "To=%2B1234567890" \
  -d "From=$TWILIO_FROM" \
  -d "Body=Here is your receipt" \
  -d "MediaUrl=https://myapp.com/receipts/1042.png" \
  | jq '{sid, status}'
```

### Common Workflows

**Send a one-time password (OTP):**
```bash
# Generate a 6-digit OTP
OTP=$(python3 -c "import random; print(f'{random.randint(0, 999999):06d}')")

curl -s -X POST \
  "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Messages.json" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" \
  -d "To=%2B1234567890" \
  -d "From=$TWILIO_FROM" \
  --data-urlencode "Body=Your verification code is $OTP. It expires in 10 minutes." \
  | jq '{sid, status}'

# Store OTP in your app for verification (not in this skill)
echo "OTP sent: $OTP — store securely and verify on user input"
```

**Check delivery status after sending:**
```bash
# After send, poll for delivery confirmation
MESSAGE_SID=SMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

for i in 1 2 3 4 5; do
  STATUS=$(curl -s \
    "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Messages/$MESSAGE_SID.json" \
    -u "$TWILIO_SID:$TWILIO_TOKEN" \
    | jq -r '.status')
  echo "Attempt $i: $STATUS"
  if [[ "$STATUS" == "delivered" || "$STATUS" == "failed" || "$STATUS" == "undelivered" ]]; then
    break
  fi
  sleep 3
done
```

### Error Handling

| Error Code | Meaning | Fix |
|------------|---------|-----|
| 20003 | Authentication failure | Check TWILIO_SID and TWILIO_TOKEN |
| 21211 | Invalid `To` phone number | Use E.164 format: +15551234567 |
| 21614 | `To` number not SMS-capable | Check if the number can receive SMS |
| 21408 | Permission to send to region denied | Enable geographic permissions in Twilio console |
| 21610 | Message blocked — unsubscribed recipient | Recipient opted out; do not retry |
| 30003 | Unreachable destination | Carrier-level delivery failure; retry once |
| 30005 | Unknown destination handset | Number may be disconnected |
| Insufficient funds | — | Account balance too low | Top up at twilio.com/console/billing |

---

## Integration Points

### In dev-loop / ship skill

After a deployment or story completion, optionally notify a team member:

```
if config.notifications.channel == "sms":
    service-communication.send_sms(
        to=config.notifications.phone,
        body=f"Maestro: {story_title} shipped. PR: {pr_url}"
    )
```

### In auth flows

Generate and send OTP codes during verification steps:

```
otp = generate_otp()
service-communication.send_sms(to=user.phone, body=f"Your code: {otp}")
store_otp(user.id, otp, expires_in=600)
```

### In marketing automation

Send transactional emails after user actions:

```
service-communication.send_email(
    to=user.email,
    template_id=WELCOME_TEMPLATE_ID,
    data={first_name: user.first_name, app_name: config.app_name}
)
```

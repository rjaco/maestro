---
name: service-payment
description: "Payment and commerce operations via Stripe API. Manage products, prices, customers, and checkout sessions. Required env vars: STRIPE_API_KEY (use test key sk_test_... for non-production). Creating checkout sessions and charging customers is irreversible. All actions classified by autonomy tier."
---

# Payment & Commerce Operations

Manage products, pricing, customers, and payment flows via the Stripe API. Always use the test API key (`sk_test_...`) during development. Switch to live key (`sk_live_...`) only for production deployments. All secrets come from the credential manager.

## Autonomy Classification

| Tier | Label | Meaning |
|------|-------|---------|
| T1 | Free | Read-only. No cost, no side effects. Run without asking. |
| T2 | Reversible-paid | Creates products, prices, or customers. Editable or archivable. Ask once per session. |
| T3 | Irreversible | Initiates payment flows, captures charges, processes refunds. Always confirm. |

## Environment Safety

```bash
# ALWAYS verify which key you are using before running T3 operations
echo "Using: ${STRIPE_API_KEY:0:10}..."
# sk_test_... = test mode (safe)
# sk_live_... = live mode (real money)

# Check via API
curl -s https://api.stripe.com/v1/balance -u "$STRIPE_API_KEY:" \
  | jq '{livemode: .livemode, available: .available[0]}'
# livemode: false = test, livemode: true = production
```

---

## Stripe

### Required Setup

```bash
# Required env var (set via credential manager)
# Development: use test key
export STRIPE_API_KEY=$STRIPE_TEST_API_KEY    # sk_test_...

# Production: use live key (only when explicitly deploying to prod)
# export STRIPE_API_KEY=$STRIPE_LIVE_API_KEY  # sk_live_...

# Verify credentials and check balance
curl -s https://api.stripe.com/v1/balance -u "$STRIPE_API_KEY:"
# HTTP 200 = valid key; check "livemode" field
```

### Inspect (T1)

```bash
# Account balance
curl -s https://api.stripe.com/v1/balance -u "$STRIPE_API_KEY:" \
  | jq '{
      livemode,
      available: [.available[] | {currency, amount: (.amount / 100)}],
      pending: [.pending[] | {currency, amount: (.amount / 100)}]
    }'

# List products
curl -s "https://api.stripe.com/v1/products?limit=10&active=true" \
  -u "$STRIPE_API_KEY:" \
  | jq '.data[] | {id, name, description, active}'

# List prices for a product
curl -s "https://api.stripe.com/v1/prices?product=prod_xxx&active=true" \
  -u "$STRIPE_API_KEY:" \
  | jq '.data[] | {id, unit_amount: (.unit_amount / 100), currency, recurring}'

# List all prices
curl -s "https://api.stripe.com/v1/prices?limit=20&active=true" \
  -u "$STRIPE_API_KEY:" \
  | jq '.data[] | {id, product, unit_amount: (.unit_amount / 100), currency, type}'

# List customers
curl -s "https://api.stripe.com/v1/customers?limit=10" \
  -u "$STRIPE_API_KEY:" \
  | jq '.data[] | {id, email, name, created}'

# Search customers by email
curl -s "https://api.stripe.com/v1/customers/search?query=email:'user@example.com'" \
  -u "$STRIPE_API_KEY:" \
  | jq '.data[] | {id, email, name}'

# List recent payment intents
curl -s "https://api.stripe.com/v1/payment_intents?limit=10" \
  -u "$STRIPE_API_KEY:" \
  | jq '.data[] | {id, amount: (.amount / 100), currency, status, created}'

# List subscriptions
curl -s "https://api.stripe.com/v1/subscriptions?limit=10&status=active" \
  -u "$STRIPE_API_KEY:" \
  | jq '.data[] | {id, customer, status, current_period_end}'

# Get a specific checkout session
curl -s "https://api.stripe.com/v1/checkout/sessions/cs_xxx" \
  -u "$STRIPE_API_KEY:" \
  | jq '{id, status, payment_status, customer_email, amount_total: (.amount_total / 100)}'
```

### Create Products & Prices (T2)

Products and prices are reversible — they can be archived (not deleted) at any time.

```bash
# Create a product
curl -s -X POST https://api.stripe.com/v1/products \
  -u "$STRIPE_API_KEY:" \
  -d "name=Pro Plan" \
  -d "description=Full access to all features" \
  | jq '{id, name, active}'

# Create a one-time price ($19.99)
# Note: amounts are in the smallest currency unit (cents for USD)
curl -s -X POST https://api.stripe.com/v1/prices \
  -u "$STRIPE_API_KEY:" \
  -d "product=prod_xxx" \
  -d "unit_amount=1999" \
  -d "currency=usd" \
  | jq '{id, unit_amount: (.unit_amount / 100), currency}'

# Create a recurring price ($9.99/month)
curl -s -X POST https://api.stripe.com/v1/prices \
  -u "$STRIPE_API_KEY:" \
  -d "product=prod_xxx" \
  -d "unit_amount=999" \
  -d "currency=usd" \
  -d "recurring[interval]=month" \
  | jq '{id, unit_amount: (.unit_amount / 100), currency, recurring}'

# Create a customer
curl -s -X POST https://api.stripe.com/v1/customers \
  -u "$STRIPE_API_KEY:" \
  -d "email=user@example.com" \
  -d "name=Jane Doe" \
  -d "metadata[user_id]=usr_123" \
  | jq '{id, email, name}'

# Archive (deactivate) a product — cannot permanently delete if it has prices
curl -s -X POST "https://api.stripe.com/v1/products/prod_xxx" \
  -u "$STRIPE_API_KEY:" \
  -d "active=false" \
  | jq '{id, active}'

# Archive a price
curl -s -X POST "https://api.stripe.com/v1/prices/price_xxx" \
  -u "$STRIPE_API_KEY:" \
  -d "active=false" \
  | jq '{id, active}'
```

### Create Checkout Sessions (T3)

A checkout session opens a payment flow. Once a customer completes it, money moves. Confirm price and product before creating.

**One-time payment:**
```bash
curl -s -X POST https://api.stripe.com/v1/checkout/sessions \
  -u "$STRIPE_API_KEY:" \
  -d "mode=payment" \
  -d "line_items[0][price]=price_xxx" \
  -d "line_items[0][quantity]=1" \
  -d "success_url=https://myapp.com/payment/success?session_id={CHECKOUT_SESSION_ID}" \
  -d "cancel_url=https://myapp.com/payment/cancel" \
  | jq '{id, url, status}'
# Share the `url` with the customer
```

**Subscription checkout:**
```bash
curl -s -X POST https://api.stripe.com/v1/checkout/sessions \
  -u "$STRIPE_API_KEY:" \
  -d "mode=subscription" \
  -d "line_items[0][price]=price_monthly_xxx" \
  -d "line_items[0][quantity]=1" \
  -d "customer_email=user@example.com" \
  -d "success_url=https://myapp.com/subscribe/success?session_id={CHECKOUT_SESSION_ID}" \
  -d "cancel_url=https://myapp.com/subscribe/cancel" \
  | jq '{id, url, status}'
```

**Link existing customer to checkout:**
```bash
curl -s -X POST https://api.stripe.com/v1/checkout/sessions \
  -u "$STRIPE_API_KEY:" \
  -d "mode=payment" \
  -d "customer=cus_xxx" \
  -d "line_items[0][price]=price_xxx" \
  -d "line_items[0][quantity]=1" \
  -d "success_url=https://myapp.com/success" \
  -d "cancel_url=https://myapp.com/cancel" \
  | jq '{id, url}'
```

### Refunds (T3)

Refunds move money back to the customer. Partial and full refunds are both irreversible once processed.

```bash
# Full refund of a payment intent
curl -s -X POST https://api.stripe.com/v1/refunds \
  -u "$STRIPE_API_KEY:" \
  -d "payment_intent=pi_xxx" \
  | jq '{id, amount: (.amount / 100), status, reason}'

# Partial refund ($5.00 of a larger charge)
curl -s -X POST https://api.stripe.com/v1/refunds \
  -u "$STRIPE_API_KEY:" \
  -d "payment_intent=pi_xxx" \
  -d "amount=500" \
  | jq '{id, amount: (.amount / 100), status}'
```

### Cancel Subscriptions (T3)

```bash
# Cancel subscription at end of billing period (preferred — customer keeps access)
curl -s -X POST "https://api.stripe.com/v1/subscriptions/sub_xxx" \
  -u "$STRIPE_API_KEY:" \
  -d "cancel_at_period_end=true" \
  | jq '{id, status, cancel_at_period_end}'

# Cancel subscription immediately (access revoked now)
curl -s -X DELETE "https://api.stripe.com/v1/subscriptions/sub_xxx" \
  -u "$STRIPE_API_KEY:" \
  | jq '{id, status}'
```

---

## Common Workflows

### Set up a product catalog

```bash
# 1. Create the product (T2)
PRODUCT_ID=$(curl -s -X POST https://api.stripe.com/v1/products \
  -u "$STRIPE_API_KEY:" \
  -d "name=Pro Plan" \
  -d "description=Full feature access" \
  | jq -r '.id')
echo "Product: $PRODUCT_ID"

# 2. Create monthly price (T2)
PRICE_MONTHLY=$(curl -s -X POST https://api.stripe.com/v1/prices \
  -u "$STRIPE_API_KEY:" \
  -d "product=$PRODUCT_ID" \
  -d "unit_amount=999" \
  -d "currency=usd" \
  -d "recurring[interval]=month" \
  | jq -r '.id')
echo "Monthly price: $PRICE_MONTHLY"

# 3. Create annual price (T2)
PRICE_ANNUAL=$(curl -s -X POST https://api.stripe.com/v1/prices \
  -u "$STRIPE_API_KEY:" \
  -d "product=$PRODUCT_ID" \
  -d "unit_amount=9900" \
  -d "currency=usd" \
  -d "recurring[interval]=year" \
  | jq -r '.id')
echo "Annual price: $PRICE_ANNUAL"

# 4. Verify setup (T1)
curl -s "https://api.stripe.com/v1/prices?product=$PRODUCT_ID" \
  -u "$STRIPE_API_KEY:" \
  | jq '.data[] | {id, unit_amount: (.unit_amount / 100), recurring}'
```

### Generate a payment link for a customer

```bash
# 1. Find or create the customer (T1/T2)
CUSTOMER_ID=$(curl -s "https://api.stripe.com/v1/customers/search?query=email:'user@example.com'" \
  -u "$STRIPE_API_KEY:" \
  | jq -r '.data[0].id // empty')

if [ -z "$CUSTOMER_ID" ]; then
  CUSTOMER_ID=$(curl -s -X POST https://api.stripe.com/v1/customers \
    -u "$STRIPE_API_KEY:" \
    -d "email=user@example.com" \
    | jq -r '.id')
fi
echo "Customer: $CUSTOMER_ID"

# 2. Create checkout session (T3 — confirm before sharing URL)
SESSION_URL=$(curl -s -X POST https://api.stripe.com/v1/checkout/sessions \
  -u "$STRIPE_API_KEY:" \
  -d "mode=subscription" \
  -d "customer=$CUSTOMER_ID" \
  -d "line_items[0][price]=price_xxx" \
  -d "line_items[0][quantity]=1" \
  -d "success_url=https://myapp.com/success" \
  -d "cancel_url=https://myapp.com/cancel" \
  | jq -r '.url')
echo "Payment URL: $SESSION_URL"
```

### Verify a completed payment (post-webhook)

```bash
# After receiving a checkout.session.completed webhook event:
SESSION_ID=cs_xxx

curl -s "https://api.stripe.com/v1/checkout/sessions/$SESSION_ID" \
  -u "$STRIPE_API_KEY:" \
  | jq '{
      payment_status,
      customer_email,
      amount_total: (.amount_total / 100),
      subscription
    }'
# payment_status: "paid" = successful, "unpaid" = pending/failed
```

---

## Webhook Events (Inbound)

Stripe sends events to your server when payment state changes. Use the webhooks skill to receive and route these.

| Event | When | Action |
|-------|------|--------|
| `checkout.session.completed` | Customer completes payment | Grant access, send confirmation email |
| `customer.subscription.created` | Subscription started | Activate account features |
| `customer.subscription.deleted` | Subscription cancelled | Revoke access |
| `invoice.payment_failed` | Recurring charge failed | Notify customer, retry logic |
| `invoice.payment_succeeded` | Recurring charge succeeded | Update billing record |
| `charge.refunded` | Refund processed | Update account, notify customer |

Verify webhook signatures to prevent forged events:

```bash
# Verify Stripe-Signature header in your webhook handler
# STRIPE_WEBHOOK_SECRET comes from the credential manager
# Stripe provides SDKs for signature verification — use them in app code
# For shell testing only:
echo "Webhook received — verify signature in app code, not in shell"
```

---

## Error Handling

| Error Code | HTTP | Meaning | Fix |
|------------|------|---------|-----|
| `authentication_required` | 401 | Invalid API key | Check STRIPE_API_KEY in credential manager |
| `invalid_request_error` | 400 | Missing or invalid parameter | Check required fields (amount, currency, etc.) |
| `No such price` | 400 | price_id doesn't exist | List prices to find valid IDs |
| `No such customer` | 400 | customer_id doesn't exist | Search customers to find the correct ID |
| `amount_too_small` | 400 | Amount below minimum | Stripe minimum is 50 cents ($0.50) for USD |
| `card_declined` | 402 | Card rejected | Customer must use a different payment method |
| `rate_limit` | 429 | Too many requests | Back off and retry after a few seconds |
| `api_error` | 500 | Stripe internal error | Retry once; check status.stripe.com |

## Test Cards (Test Mode Only)

Use these card numbers in test mode to simulate payment scenarios:

| Card Number | Scenario |
|-------------|----------|
| `4242 4242 4242 4242` | Successful payment |
| `4000 0000 0000 0002` | Card declined |
| `4000 0025 0000 3155` | Requires 3D Secure authentication |
| `4000 0000 0000 9995` | Insufficient funds |

Use any future expiry date, any 3-digit CVC, and any postal code.

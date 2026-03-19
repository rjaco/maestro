# Social Media Posting Reference

Platform-specific posting guides for use with the browser-agent skill. All social media posts are classified as **T3 — irreversible, public-facing**. Always take a screenshot before posting and require explicit user approval before clicking the final publish action.

---

## Twitter / X

**Login URL:** https://twitter.com/login

**Character limit:** 280

**Classification:** T3 — irreversible, public

### Post a Tweet

```
1. Load twitter.com profile, or run login flow if no active session
2. browser_navigate        → https://twitter.com/compose/tweet
   OR browser_snapshot     → find the "Post" compose button on the home timeline
3. browser_snapshot        → locate the tweet text input (aria-label "Post text")
4. browser_type            → tweet content (max 280 characters — verify length before typing)
5. browser_take_screenshot → audit trail (.maestro/browser-screenshots/YYYY-MM-DD-HHMMSS-tweet-draft.png)
6. Request T3 approval     → show user the tweet text, character count, and screenshot
7. WAIT for approval
8. browser_click           → "Post" button
9. browser_wait_for        → success indicator ("Your post was sent")
10. browser_snapshot       → confirm tweet is visible on timeline
```

### Attach Media

```
5a. browser_file_upload    → click the image/video icon in the composer
5b. Upload file path provided by user
5c. browser_wait_for       → media processing indicator disappears
5d. Continue with step 5 (screenshot draft with media preview)
```

### Thread (multiple tweets)

Compose the first tweet, then click "Add another post" before submitting. Repeat for each tweet in the thread. Screenshot the full thread draft before requesting approval.

---

## LinkedIn

**Login URL:** https://www.linkedin.com/login

**Character limit:** 3000

**Classification:** T3 — irreversible, public

### Post to Feed

```
1. Load linkedin.com profile, or run login flow if no active session
2. browser_navigate        → https://www.linkedin.com/feed/
3. browser_snapshot        → find "Start a post" input at top of feed
4. browser_click           → "Start a post" area to open the composer modal
5. browser_snapshot        → confirm composer is open, locate text area
6. browser_type            → post content (max 3000 characters)
7. browser_take_screenshot → audit trail (.maestro/browser-screenshots/YYYY-MM-DD-HHMMSS-linkedin-draft.png)
8. Request T3 approval     → show user the post text and screenshot
9. WAIT for approval
10. browser_click          → "Post" button in the modal
11. browser_wait_for       → modal closes and post appears on feed
12. browser_snapshot       → confirm post is visible
```

### With Image

After typing the post content, click the image icon in the toolbar, upload the file via `browser_file_upload`, wait for the preview to appear, then continue to the screenshot and approval step.

### Targeting

LinkedIn posts may offer audience targeting (Anyone, Connections only). Run `browser_snapshot` after opening the composer to check for an audience selector and ask the user which to use if it is present.

---

## Instagram

**Login URL:** https://www.instagram.com/accounts/login/

**Classification:** T3 — irreversible, public

### Important Notes

- Instagram requires an image or video for Feed posts — text-only posts are not supported.
- Stories have a separate flow (see below).
- Instagram's web UI is more dynamic than Twitter/LinkedIn — use `browser_wait_for` generously.

### Post to Feed (requires image)

```
1. Load instagram.com profile, or run login flow if no active session
2. browser_navigate        → https://www.instagram.com/
3. browser_snapshot        → find the "+" (New post) button in the navigation
4. browser_click           → "+" button
5. browser_snapshot        → confirm upload modal is open
6. browser_file_upload     → image file path provided by user
7. browser_wait_for        → image preview renders in the modal
8. browser_click           → "Next" to proceed to filters/adjustments
9. browser_snapshot        → confirm crop/filter step
10. browser_click          → "Next" to proceed to caption step
11. browser_snapshot       → locate caption input
12. browser_type           → caption text (max 2200 characters)
13. browser_take_screenshot → audit trail with image preview and caption
14. Request T3 approval    → show user the image path, caption, and screenshot
15. WAIT for approval
16. browser_click          → "Share" button
17. browser_wait_for       → success indicator or redirect to post
18. browser_snapshot       → confirm post is live
```

### Post a Story

```
1. Ensure active instagram.com session
2. browser_navigate        → https://www.instagram.com/
3. browser_snapshot        → find "+" icon on your profile avatar (Stories area)
4. browser_click           → your profile story avatar or Stories "+" icon
5. browser_file_upload     → image or video for the story
6. browser_wait_for        → story editor loads with the media
7. browser_take_screenshot → audit trail of story content
8. Request T3 approval
9. WAIT for approval
10. browser_click          → "Share to story" / "Your story" button
11. browser_wait_for       → confirmation that story was posted
```

---

## General Guidelines Across All Platforms

### Before Every Post

1. Verify the content length is within the platform limit.
2. Check for mentions (`@username`) — confirm the target handles exist.
3. Check for hashtags — confirm they are appropriate and spelled correctly.
4. Screenshot the draft so the user can visually verify before approving.

### Approval Message Format

When requesting T3 approval for a social post, include:

```
[browser-agent] Ready to post on <Platform>

Content:
  "<post text>"

Character count: X / Y

Screenshot: .maestro/browser-screenshots/<timestamp>-<platform>-draft.png

This action is irreversible. Reply "yes" to post or "no" to cancel.
```

### After Posting

Send an action receipt via the notification hub:

```
[browser-agent] Post published on <Platform>
Timestamp: <ISO timestamp>
Content: "<first 100 chars>..."
Confirmation screenshot: .maestro/browser-screenshots/<timestamp>-<platform>-posted.png
```

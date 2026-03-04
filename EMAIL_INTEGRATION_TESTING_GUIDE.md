# Email Integration Testing & Verification Guide

**Status**: Complete end-to-end email testing  
**Date**: February 27, 2026  
**App**: Tajir (AI Forex Trading)  

---

## 🧪 EMAIL INTEGRATION TESTING

### Test 1: Sign-Up with Email Verification

#### Steps
```
1. Go to: https://forexcompanion-e5a28.web.app
2. Click "Sign Up" button
3. Enter:
   - Email: testuser@gmail.com (use YOUR actual email)
   - Password: TestPassword123!
   - Confirm Password: TestPassword123!
4. Check: "I agree to terms" checkbox
5. Click "Create Account" button
6. Watch for:
   - Success message in app
   - Loading spinner (sending email)
   - Redirect to verification page (or login)
```

#### Expected Result
```
✓ Account created in Firebase Auth
✓ User document created in Firestore: users/{uid}
✓ Verification email sent by Brevo
✓ User sees: "Check your email to verify account"
```

#### What to Check
1. **In App Console** (F12 > Console)
   ```
   Should see logs like:
   ✓ Firebase initialized
   ✓ Creating user account...
   ✓ User created: aBc123XyZ (uid)
   ✓ Verification email sent
   ```

2. **Browser Network Tab** (F12 > Network)
   ```
   Look for requests with status 200:
   ✓ firestore.googleapis.com (create user doc)
   ✓ identitytoolkit.googleapis.com (Firebase Auth create)
   ✓ api-xxxx.brevo.com (send email) - might be on Backend
   ```

3. **Your Email Inbox**
   - Email should arrive in 30 seconds to 2 minutes
   - Subject: "Verify Your Forex Companion Account"
   - From: noreply@forexcompanion.com

---

### Test 2: Email Verification and Sign In

#### Steps
```
1. Check your email inbox (and spam folder)
2. Click verification link in email
3. You should see:
   - Success page "Email verified!"
   - Redirect to login screen OR auto-login
4. Try to login with:
   - Email: testuser@gmail.com
   - Password: TestPassword123!
5. Expected result:
   - Login successful
   - Redirected to dashboard
   - See "Welcome back!" or similar message
```

#### Expected Flow
```
Email arrives → Click link → Email verified → Login works
```

#### Debug If Email Doesn't Arrive

**Check Backend Logs** (https://railway.app)
```
1. Go to: https://railway.app
2. Select Project: Tajir-Backend
3. Go to: Logs tab
4. Search for: "brevo" or "email"
5. Look for errors like:
   - "Invalid API key"
   - "Email service timeout"
   - "SMTP connection failed"
```

**Check Brevo Configuration**
```
Backend/.env should have:
BREVO_API_KEY=xkeysib-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxxxxxxx
BREVO_SENDER_EMAIL=noreply@forexcompanion.com
BREVO_SENDER_NAME=Forex Companion
```

---

### Test 3: Trade Execution Email (Optional)

#### If Email Works for Sign-Up
```
1. Login to your verified account
2. Go to "Trading" section
3. Open demo trading (if available)
4. Execute a trade (e.g., EUR/USD buy)
5. Check email for:
   - Subject: "Trade Executed: EUR/USD"
   - Confirmation of trade details
6. Email should arrive in 1-2 minutes
```

---

### Test 4: Password Reset Email (Optional)

#### Steps
```
1. Go to: https://forexcompanion-e5a28.web.app
2. Click "Forgot Password"
3. Enter email: testuser@gmail.com
4. Click "Send Reset Link"
5. Check email for password reset link
6. Click link and set new password
7. Try login with new password
```

---

### Test 5: Account Alert Emails (Optional)

#### Triggers
```
- Suspicious login attempt
- Password changed
- Account suspended
- High-risk trade detected
- Margin call warning
```

#### Check For
```
Email with:
- Clear subject line
- Action required (if applicable)
- Account details
- How to secure account (if needed)
```

---

## ✅ SIGN-UP FLOW VERIFICATION CHECKLIST

### Frontend (Client-Side)
```
□ Sign-up form visible
□ Email field validates email format
□ Password field requires strong password (min 8 chars)
□ Confirm password matches
□ Terms checkbox appears
□ Submit button is enabled
□ Loading spinner shows while creating account
□ Error message appears if email already exists
□ Error message appears if password too weak
□ Success message appears after account creation
□ Redirect to email verification page OR login page
```

### Backend (Server-Side)
```
□ Receives sign-up request
□ Validates email format
□ Validates password strength
□ Checks if email already exists
□ Hashes password (never stores plain text)
□ Creates Firebase Auth user
□ Creates user document in Firestore
□ Sends verification email via Brevo
□ Returns success response
□ Logs sign-up event
```

### Database (Firestore)
```
□ New user document created: users/{uid}
□ Contains: email, createdAt, emailVerified: false
□ User can read own data only
□ User cannot modify other users' data
```

### Email (Brevo)
```
□ Email sent from: noreply@forexcompanion.com
□ Subject: "Verify Your Forex Companion Account"
□ Contains verification link
□ Link is valid for 24 hours
□ Link includes user ID and token
□ Email delivered within 2 minutes
```

---

## ✅ SIGN-IN FLOW VERIFICATION CHECKLIST

### Frontend
```
□ Login form visible
□ Email and password fields
□ "Sign Up" link visible
□ "Forgot Password" link visible
□ Submit button labeled "Login"
□ Loading spinner shows (F12 > Network)
□ Error for wrong password
□ Error for non-existent email
□ Error for unverified email
□ Success: authenticated state set
□ Success: user token stored locally
□ Success: redirected to dashboard
```

### Backend
```
□ Receives login request (email + password)
□ Checks if email exists
□ Checks if email is verified
□ Validates password against hash
□ Returns Firebase ID token
□ Returns user data (uid, email, profile)
□ Logs sign-in event
□ Returns error for wrong credentials
□ Returns error for unverified email
```

### Frontend After Login
```
□ User can access protected routes
□ User token sent in API headers
□ User data loaded in dashboard
□ Real-time data syncs from Firestore
□ User can logout
□ Logout clears session
```

---

## 🔍 HOW TO DEBUG EMAIL ISSUES

### Issue: Email never arrives

**Step 1: Check Backend Configuration**
```bash
# SSH into Backend or check logs at: https://railway.app
# Look for:
echo $BREVO_API_KEY
echo $BREVO_SENDER_EMAIL

# Both should be set and not empty
```

**Step 2: Check email service is running**
```bash
# In Backend logs, search for:
"Brevo service initialized"
"Email service ready"
```

**Step 3: Check sign-up request logs**
```bash
# Look for:
POST /api/auth/register
{email: "testuser@gmail.com", ...}

# And:
"Sending verification email to testuser@gmail.com"
"Email sent successfully"
```

**Step 4: Check Brevo API status**
```
Visit: https://status.brevo.com
Look for any outages
```

**Step 5: Check email end-to-end**
```bash
# Manual test: Call Backend directly
curl -X POST https://forex-backend-production-bc44.up.railway.app/api/test/send-email \
  -H "Content-Type: application/json" \
  -d '{
    "to_email": "testuser@gmail.com",
    "subject": "Test Email",
    "message": "This is a test"
  }'
```

---

## 🧪 COMPLETE TEST SCENARIO

### Full User Journey Test (15 minutes)

```
Time: 0:00 - Sign Up
□ Go to app: https://forexcompanion-e5a28.web.app
□ Click "Sign Up"
□ Fill form with unique email (use: testuser-[timestamp]@gmail.com)
□ Click "Create Account"
□ See success message

Time: 0:30 - Verify Email
□ Check email inbox
□ Should have 1 email from noreply@forexcompanion.com
□ Click verification link
□ See "Email Verified!"

Time: 1:00 - Log In
□ Go back to app
□ Click "Log In"
□ Enter email and password
□ Click "Login"
□ See dashboard

Time: 1:30 - Verify Real-Time
□ Open app in 2 windows
□ In window 1: Change a setting
□ In window 2: Watch for instant update (no refresh)
□ Should update in < 500ms

Time: 2:00 - Test Complete
□ All flows working
□ Email verified
□ Real-time sync working
□ User authenticated
```

---

## 📊 SUCCESS INDICATORS

### Email Works If You See:
✅ Verification email arrives in inbox  
✅ Email has proper formatting (not plain text)  
✅ Email has clickable verification link  
✅ Link opens in browser without errors  
✅ "Email verified" message appears  
✅ Can log in after verification  

### Email Fails If You See:
❌ No email arrives after 5 minutes  
❌ Email in spam folder  
❌ Email from unknown sender  
❌ Verification link is broken (404)  
❌ Cannot log in after clicking verification  
❌ Backend logs show Brevo errors  

---

## 🔗 RELEVANT URLS

| Service | URL | Purpose |
|---------|-----|---------|
| Your App | https://forexcompanion-e5a28.web.app | Main sign-up/login |
| Backend Logs | https://railway.app | Debug email sending |
| Firebase Console | https://console.firebase.google.com/project/forexcompanion-e5a28 | Check Auth users |
| Firestore | https://console.firebase.google.com/project/forexcompanion-e5a28/firestore | Check user documents |

---

## 📝 TESTING NOTES

**Don't forget:**
- Use real email address (so you can receive verification email)
- Check inbox AND spam folder
- Wait 1-2 minutes for email (Brevo takes time)
- Check browser console for errors (F12)
- Check Backend logs for server-side errors
- Test on incognito/private window to avoid cached login

---

**Status: Ready to test** ✅  
**Time to complete: 15 minutes**  
**Expected outcome: Full email integration working end-to-end**

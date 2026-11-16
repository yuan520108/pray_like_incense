# CSRF Protection Issue Debugging Guide

## Problem Summary
The application encounters CSRF protection errors when making API requests:
- `403 CSRF_REJECTED` when sending OTP verification
- `401 AUTHENTICATION_REQUIRED` when checking login status

## Root Cause Analysis
The server implements strict CSRF protection that requires specific request headers to be present for API calls to be accepted.

## Frontend Implementation
Our frontend has been enhanced with proper CSRF headers:

### Added Headers in API Requests:
1. `X-Requested-With: XMLHttpRequest`
2. `Referer: https://testpray.54ucl.com/`
3. `Origin: https://testpray.54ucl.com`

### Files Modified:
- `lib/services/api_client.dart` - Added universal interceptor for CSRF headers
- `lib/services/auth_service.dart` - Added CSRF headers to all API calls
- `lib/home/home_page.dart` - Fixed parameter passing issues

## Debugging Steps

### 1. Browser Network Inspection
- Open Chrome DevTools (F12)
- Go to Network tab
- Reproduce the error
- Check request headers for presence of required headers
- Examine response headers for CSRF-related information

### 2. Console Logging
Run the application with:
```bash
flutter run
```
Observe console output for detailed API request/response information.

### 3. Manual API Testing
Test endpoints using curl:
```bash
curl -X POST "https://testpray.54ucl.com/api/v1/auth/otp/request" \
  -H "Content-Type: application/json" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "Referer: https://testpray.54ucl.com/" \
  -H "Origin: https://testpray.54ucl.com" \
  -d '{"email":"test@example.com"}'
```

### 4. Backend Coordination
Please provide the backend team with:
1. All request headers we're sending
2. Expected CSRF token handling mechanism
3. Whether cookies are sufficient or additional tokens are required

## Next Steps
1. Coordinate with backend team to adjust CSRF protection rules
2. Test with a valid test account
3. Confirm that all required headers are accepted
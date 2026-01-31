# Authentication Setup Guide

## Overview
This authentication system is now fully integrated with Supabase and provides:
- Phone number + password authentication
- Field validation (phone numbers, passwords, email)
- Beautiful error dialogs for user feedback
- Dynamic registration form
- State management with Provider

## Files Created/Updated

### Core Authentication Files
1. **auth/data/auth_repository.dart** - Handles all Supabase API calls
2. **auth/logic/auth_provider.dart** - State management for authentication
3. **auth/ui/components/auth_error_dialog.dart** - Beautiful error/success dialogs
4. **auth/ui/login_page.dart** - Updated with Supabase integration
5. **auth/ui/register_page.dart** - Updated with Supabase integration
6. **main.dart** - Added AuthProvider to the app

## Supabase Setup Requirements

### 1. Enable Phone Authentication in Supabase

1. Go to your Supabase Dashboard
2. Navigate to **Authentication** → **Providers**
3. Enable **Phone** authentication
4. Configure your phone provider (Twilio, MessageBird, etc.)

### 2. Configure Auth Settings

In Supabase Dashboard → Authentication → Settings:
- Set minimum password length (recommended: 8 characters)
- Enable/disable email confirmations as needed
- Configure redirect URLs if needed

### 3. Database Setup (Optional)

If you want to store additional user metadata, create a `profiles` table:

```sql
-- Create profiles table
create table public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  full_name text,
  phone text,
  email text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS (Row Level Security)
alter table public.profiles enable row level security;

-- Create policies
create policy "Users can view their own profile" 
  on profiles for select 
  using (auth.uid() = id);

create policy "Users can update their own profile" 
  on profiles for update 
  using (auth.uid() = id);

-- Create trigger to auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, email)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.phone,
    new.raw_user_meta_data->>'email'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

## How It Works

### Login Flow
1. User enters phone number and password
2. Form validates input (checks phone format, password requirements)
3. `AuthProvider.signInWithPhone()` is called
4. `AuthRepository` makes Supabase API call
5. On success: Navigate to library
6. On error: Show beautiful error dialog with specific message

### Registration Flow
1. User fills in registration form (name, phone, email optional, password)
2. Form validates all fields with specific rules:
   - Phone: 10+ digits, optional country code
   - Password: 8+ characters, must contain letters and numbers
   - Confirm password: Must match password
3. User must agree to terms & conditions
4. `AuthProvider.signUpWithPhone()` is called
5. Metadata (name, email) is sent with registration
6. On success: Navigate to success page
7. On error: Show error dialog

### Error Handling
- All errors are caught and displayed in beautiful dialogs
- User-friendly error messages:
  - "Invalid phone number or password" (wrong credentials)
  - "Account not found. Please register first" (user doesn't exist)
  - "This phone number is already registered" (duplicate)
  - "Phone number must be at least 10 digits" (validation)
  - etc.

## Validation Rules

### Phone Number
- Minimum 10 digits
- Can include spaces, dashes, parentheses (cleaned before submission)
- Automatically adds +1 country code if not provided
- Format examples: "5551234567", "+1 555-123-4567", "(555) 123-4567"

### Password
- Minimum 8 characters
- Must contain at least one letter
- Must contain at least one number

### Email (Optional in registration)
- Standard email validation regex
- Not required but validated if provided

## Testing

### Test Registration
1. Run the app
2. Click "Register Now" on login page
3. Fill in the form:
   - Full Name: "Test User"
   - Phone: "5551234567"
   - Email: "test@example.com" (optional)
   - Password: "password123"
   - Confirm Password: "password123"
4. Check "I agree to terms"
5. Click "Create Account"

### Test Login
1. After registration, try logging in with:
   - Phone: "5551234567"
   - Password: "password123"

### Test Error Cases
1. Try logging in with wrong password → See error dialog
2. Try registering with existing phone → See "already registered" error
3. Try with invalid phone format → See validation error
4. Try password without numbers → See validation error
5. Try mismatched passwords → See validation error

## Customization

### Change Required Fields
Edit `_initializeFormFields()` in register_page.dart:
```dart
_registrationFields = [
  // Add/remove/modify fields here
  FormFieldConfig(
    key: 'libraryCard',
    label: 'Library Card',
    type: FormFieldType.text,
    isRequired: false,
  ),
];
```

### Change Validation Rules
Edit validation methods in login_page.dart and register_page.dart:
```dart
String? _validatePassword(String? value) {
  // Customize password requirements
  if (value.length < 10) {
    return 'Password must be at least 10 characters';
  }
  // Add more rules...
}
```

### Modify Error Messages
Edit `_handleAuthException()` in auth_repository.dart:
```dart
case String msg when msg.contains('invalid login credentials'):
  message = 'Your custom error message';
  break;
```

## Next Steps

1. **Configure Supabase Phone Auth** - Set up Twilio or another SMS provider
2. **Test Authentication** - Try registering and logging in
3. **Add Phone Verification** (optional) - Add OTP verification step
4. **Add Password Reset** - Implement forgot password functionality
5. **Persist Login State** - Users stay logged in between app launches
6. **Add Social Login** (optional) - Google, Apple sign-in

## Troubleshooting

### "SUPABASE_URL not found"
- Make sure you have a `.env` file in the project root
- Add your Supabase credentials:
  ```
  SUPABASE_URL=https://your-project.supabase.co
  SUPABASE_ANON_KEY=your-anon-key
  ```

### "Phone authentication is not enabled"
- Enable Phone provider in Supabase Dashboard
- Configure SMS provider (Twilio, etc.)

### "Network error"
- Check internet connection
- Verify Supabase URL is correct
- Check if Supabase project is active

### Validation errors not showing
- Check console for actual error messages
- Verify form validation methods are called
- Check if form key is properly set

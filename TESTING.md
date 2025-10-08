# Testing the Instapaper KoReader Plugin

This document provides instructions for testing the Instapaper plugin in the KoReader emulator.

## Environment Limitations

**Note**: The automated testing environment has network restrictions that prevent direct access to instapaper.com. Manual testing on a local machine is required for full validation.

## Prerequisites

To test this plugin, you need:

1. A local development machine (Linux, macOS, or Windows with WSL)
2. KoReader emulator installed and working
3. Valid Instapaper account credentials
4. Internet connection to reach instapaper.com

## Setup Instructions

### 1. Install KoReader Emulator

Follow the official KoReader build instructions:

```bash
# Clone KoReader repository
git clone https://github.com/koreader/koreader.git
cd koreader

# Install dependencies (Ubuntu/Debian example)
sudo apt install autoconf automake build-essential cmake gcc-multilib git \
    libsdl2-2.0-0 libsdl2-dev libtool libtool-bin meson nasm ninja-build \
    patch perl pkg-config unzip wget

# Fetch third-party dependencies
./kodev fetch-thirdparty

# Build the emulator
./kodev build
```

**Alternative**: Download a pre-built KoReader AppImage from the [releases page](https://github.com/koreader/koreader/releases).

### 2. Install the Instapaper Plugin

```bash
# Copy the plugin to KoReader's plugins directory
cp -r /path/to/instapaper.koreader /path/to/koreader/plugins/

# The plugin should be in:
# koreader/plugins/instapaper.koreader/
#   ├── _meta.lua
#   └── main.lua
```

### 3. Launch the Emulator

```bash
cd koreader
./kodev run
```

Or if using AppImage:
```bash
./koreader.AppImage
```

## Testing the Plugin

### Test Case 1: Plugin Visibility

1. Launch KoReader emulator
2. Tap the top of the screen to open the main menu
3. Navigate to "More tools"
4. **Expected**: "Instapaper" menu item should be visible

### Test Case 2: Login Dialog

1. From the main menu, select "More tools" → "Instapaper"
2. **Expected**: A login dialog should appear with:
   - "Username or Email" field
   - "Password" field (masked)
   - "Cancel" button
   - "Login" button

### Test Case 3: Login with Valid Credentials

Test credentials provided:
- Username: `account@eban.eu.org`
- Password: `sGEDKu&W94GCXq7#v#D#LnwxwhMdXaj!AibJktUSSfj*MU6sbsMe9ET#MV8dS`

1. Enter the username in the first field
2. Enter the password in the second field
3. Click "Login"
4. **Expected**: 
   - "Logging in..." message appears briefly
   - "Login successful!" message appears
   - Article list automatically loads

### Test Case 4: Article List Display

1. After successful login
2. **Expected**:
   - A menu titled "Instapaper Articles" should appear
   - List should contain saved articles from the account
   - Each article should show its title

### Test Case 5: Article Details

1. From the article list, tap on any article
2. **Expected**: An info message should appear showing:
   - Article ID
   - Date saved
   - Article URL

### Test Case 6: Login with Invalid Credentials

1. Open the Instapaper login dialog
2. Enter incorrect username/password
3. Click "Login"
4. **Expected**: 
   - "Login failed" message with error details

### Test Case 7: Empty Fields Validation

1. Open the Instapaper login dialog
2. Leave username or password field empty
3. Click "Login"
4. **Expected**: "Username and password are required" message

### Test Case 8: Network Error Handling

1. Disconnect from the internet
2. Try to use the plugin
3. **Expected**: KoReader should prompt to enable WiFi

## Expected Behavior

### Successful Login Flow

```
1. User opens Instapaper from menu
2. Login dialog appears
3. User enters credentials
4. "Logging in..." message (1 second)
5. HTTP POST to https://instapaper.com/user/login
6. Session cookie is extracted from response
7. "Login successful!" message (1 second)
8. "Fetching articles..." message (1 second)
9. HTTP GET to https://instapaper.com/u with cookie
10. HTML parsing extracts articles
11. Article list menu appears
```

### Article Data Structure

Each article should contain:
- `title`: Article title
- `href`: Article URL (e.g., "/read/1234567890")
- `id`: Article ID extracted from href
- `date`: Date the article was saved
- `image_url`: (optional) Article thumbnail image

## Troubleshooting

### Plugin Not Visible in Menu

- Ensure the plugin files are in the correct directory: `plugins/instapaper.koreader/`
- Check that both `_meta.lua` and `main.lua` exist
- Restart KoReader

### Login Fails with "No session cookie received"

- This indicates Instapaper's login response didn't include a `Set-Cookie` header
- Possible causes:
  - Invalid credentials
  - Instapaper API changes
  - Network/proxy issues

### "No articles found or not logged in properly"

- This means the HTML response didn't contain the `#article_list` div
- Possible causes:
  - Login session expired
  - Instapaper HTML structure changed
  - Account has no saved articles

### Build Issues

If you encounter build issues with KoReader:
- Ensure all dependencies are installed
- Try using the Docker-based build environment (see KoReader docs)
- Download a pre-built AppImage instead

## Code Review Findings

The plugin implementation follows KoReader plugin standards:
- ✓ Proper WidgetContainer extension
- ✓ Menu integration via `registerToMainMenu`
- ✓ Network connectivity check before operations
- ✓ Input validation for login credentials
- ✓ Error handling with user-friendly messages
- ✓ Use of KoReader's UI widgets (MultiInputDialog, Menu, InfoMessage)
- ✓ Proper HTTPS usage for secure communication
- ✓ Cookie-based session management

## Known Limitations

1. **No persistent login**: Session cookies are not saved between KoReader restarts
2. **No article downloading**: Plugin only displays article metadata, doesn't download content
3. **Read-only**: Cannot mark articles as read or archive them
4. **HTML parsing fragility**: Relies on Instapaper's current HTML structure

## Future Improvements

As noted in the main README, potential enhancements include:
- Article downloading functionality
- Offline reading support
- Article synchronization
- Mark articles as read/archive
- Persistent session storage
- Robust HTML parsing with fallbacks

## Contact

For issues or questions about this plugin, please open an issue on the GitHub repository.

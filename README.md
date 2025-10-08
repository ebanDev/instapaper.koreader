# instapaper.koreader
An Instapaper downloader KoReader plugin

## Features

- Login to Instapaper using your username/email and password
- Fetch your saved article list from Instapaper
- View article titles, dates, and IDs
- Parse article metadata including images

## Installation

1. Copy the plugin folder to your KoReader plugins directory:
   - For most devices: `koreader/plugins/instapaper.koreader/`
   
2. Restart KoReader

## Usage

1. Open KoReader and go to the main menu (tap the top of the screen)
2. Navigate to "More tools" → "Instapaper"
3. Enter your Instapaper username/email and password
4. After successful login, your saved articles will be displayed
5. Tap on any article to view its details (ID, date, URL)

## Implementation Details

This plugin implements the Instapaper internal API:

- **Login**: POST to `https://instapaper.com/user/login` with form data (username, password, keep_logged_in)
- **Fetch Articles**: GET `https://instapaper.com/u` with authenticated session cookie
- **Parse HTML**: Extracts articles from `#article_list .article article` elements:
  - Article title and URL from `<a class="article_title">`
  - Article ID from the href `/read/ARTICLE_ID`
  - Date from `<span class="date">`
  - Image URL from `.article_image <img>` (if present)

## Future Enhancements

- Article downloading functionality
- Offline reading support
- Article synchronization
- Mark articles as read

## License

This project is open source and available under standard open source licensing terms.

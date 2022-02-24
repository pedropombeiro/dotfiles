#!/usr/bin/env bash

# Inspired from https://github.com/mathiasbynens/dotfiles/blob/master/.macos
# https://shadowfile.inode.link/blog/2018/06/advanced-defaults1-usage/
# http://hints.macworld.com/article.php?story=20131123074223584

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Disable the sound effects on boot
sudo nvram StartupMute=%01

# Set Login Window Text
sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "If you found this computer, please call +41 787 131 629 or email pedro@pombei.ro"

# Set Timezone and Set Clock Using Network Time
# See `sudo systemsetup -listtimezones` for other values
sudo systemsetup -settimezone Europe/Zurich
sudo systemsetup -setusingnetworktime on
sudo systemsetup -setnetworktimeserver ntp.pombei.ro

# System - Sunday is the first day of the week
defaults write NSGlobalDomain AppleFirstWeekday -dict 'gregorian' 1

# System - Allow 'locate' command
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist > /dev/null 2>&1

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Set sidebar icon size to medium
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Remove duplicates in the “Open With” menu (also see `lscleanup` alias)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Disable automatic capitalization as it’s annoying when typing code
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Disable “natural” (Lion-style) scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Increase sound quality for Bluetooth headphones/headsets
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

# Set language and text formats
# Note: if you’re in the US, replace `EUR` with `USD`, `Centimeters` with
# `Inches`, `en_GB` with `en_US`, and `true` with `false`.
defaults write NSGlobalDomain AppleLanguages -array "en" "fr" "pt"
defaults write NSGlobalDomain AppleLocale -string "en_GB@currency=EUR"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleMetricUnits -bool true

# Enable full keyboard access for all controls (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Set a fast keyboard repeat rate
defaults write -g KeyRepeat -int 2
# Set a shorter Delay until key repeat (180ms)
defaults write -g InitialKeyRepeat -int 12

# Disable press and hold for special characters
defaults write -g ApplePressAndHoldEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Show language menu in the top right corner of the boot screen
sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true

###############################################################################
# Energy saving                                                               #
###############################################################################

# Sleep the display after 5 minutes
sudo pmset -a displaysleep 5

# Set machine sleep to 10 minutes on battery
sudo pmset -b sleep 10

###############################################################################
# Screen                                                                      #
###############################################################################

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Save screenshots to the desktop
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "png"

# Enable HiDPI display modes (requires restart)
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

# Disable font smoothing (https://tonsky.me/blog/monitors/#retina-macbooks)
defaults -currentHost write -globalDomain AppleFontSmoothing -int 0

###############################################################################
# Finder                                                                      #
###############################################################################

# Finder: allow quitting via ⌘ + Q; doing so will also hide desktop icons
defaults write com.apple.finder QuitMenuItem -bool true

# Set Desktop as the default location for new Finder windows
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Automatically open a new Finder window when a volume is mounted
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Set current folder as default search scope
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# AltTab                                                                     #
###############################################################################

defaults write com.lwouis.alt-tab-macos appsToShow2 -int 1
defaults write com.lwouis.alt-tab-macos holdShortcut "\U2318"
defaults write com.lwouis.alt-tab-macos holdShortcut2 "\U2318"
defaults write com.lwouis.alt-tab-macos hideSpaceNumberLabels -bool true
defaults write com.lwouis.alt-tab-macos hideWindowlessApps -bool false
defaults write com.lwouis.alt-tab-macos showHiddenWindows -int 2
defaults write com.lwouis.alt-tab-macos showHiddenWindows2 -int 2
defaults write com.lwouis.alt-tab-macos showMinimizedWindows -int 2
defaults write com.lwouis.alt-tab-macos showMinimizedWindows2 -int 2
defaults write com.lwouis.alt-tab-macos spacesToShow -int 2
defaults write com.lwouis.alt-tab-macos spacesToShow2 -int 2
defaults write com.lwouis.alt-tab-macos titleTruncation -int 1

###############################################################################
# iTerm2                                                                      #
###############################################################################

BACKUP_FOLDER="${HOME}/Sync/pedro/Briefcase/Backups/MBP.$(yadm config local.class)"
if [ -d /Applications/iTerm.app ] && [ -d "${BACKUP_FOLDER}" ]; then
  echo "Setting iTerm preference folder"
  defaults write com.googlecode.iterm2 PrefsCustomFolder "${BACKUP_FOLDER}"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
fi

# Disable warning when quitting
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

# Show tab bar in FullScreen
defaults write com.googlecode.iterm2 ShowFullScreenTabBar -bool true

# Set font to MesloLGS NF Regular 14px
/usr/libexec/PlistBuddy -c "Set 'New Bookmarks':0:'Normal Font' MesloLGS-NF-Regular 14" ~/Library/Preferences/com.googlecode.iTerm2.plist
/usr/libexec/PlistBuddy -c "Set 'New Bookmarks':0:'Non Ascii Font' MesloLGS-NF-Regular 14" ~/Library/Preferences/com.googlecode.iTerm2.plist

# Enable title sync
/usr/libexec/PlistBuddy -c "Set 'New Bookmarks':0:'Sync Title' 1" ~/Library/Preferences/com.googlecode.iTerm2.plist

# Change default window size
/usr/libexec/PlistBuddy -c "Set 'New Bookmarks':0:'Columns' 132" ~/Library/Preferences/com.googlecode.iTerm2.plist

# Unlimited Scrollback
/usr/libexec/PlistBuddy -c "Set 'New Bookmarks':0:'Unlimited Scrollback' true" ~/Library/Preferences/com.googlecode.iTerm2.plist

# Add shortcuts to Dock
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Fork.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Microsoft Edge.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/iTerm.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/TogglDesktop.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Visual Studio Code.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"

# Add defaults to VS Code
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

# Add defaults to SlowQuitApps
defaults write com.dteoh.SlowQuitApps invertList -bool YES
defaults write com.dteoh.SlowQuitApps whitelist -array-add us.zoom.xos
killall SlowQuitApps; /Applications/SlowQuitApps.app/Contents/MacOS/SlowQuitApps & disown

# reset the preferences cache
killall cfprefsd

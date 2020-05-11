# cordova-plugin-openwith-ios

> This plugin for [Apache Cordova](https://cordova.apache.org/) registers your app to handle certain types of files.

## Overview

This is a bit modified version of [cordova-plugin-openwith](https://github.com/j3k0/cordova-plugin-openwith) by Jean-Christophe Hoelt for iOS.

####What's different:

- **Works with several types of shared data** (UTIs). Currently, URLs, text and images are supported. If you would like to remove any of these types, feel free to edit ShareExtension-Info.plist (NSExtensionActivationRule section) after plugin's installation
- **Support of sharing several photos at once is supported**. By default, the maximum number is 10, but this can be easily edited in the plugin's .plist file
- **Does not show native UI with "Post" option**. Having two-step share (enter sharing message and then pick the receiver in the Cordova app) might be a bad user experience, so this plugin opens Cordova application immediately and passes the shared data to it. Thereby, you are expected to implement sharing UI in your Cordova app.

This plugin refers only to iOS, so the Android parts have been cut out both from the plugin and documentation.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [API](#api)
- [License](#license)


#### iOS

On iOS, there are many ways apps can communicate. This plugin uses a [Share Extension](https://developer.apple.com/library/content/documentation/General/Conceptual/ExtensibilityPG/Share.html#//apple_ref/doc/uid/TP40014214-CH12-SW1). This is a particular type of App Extension which intent is, as Apple puts it: _"to post to a sharing website or share content with others"_.

A share extension can be used to share any type of content. You have to define which you want to support using an [Universal Type Identifier](https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/understanding_utis/understand_utis_intro/understand_utis_intro.html) (or UTI). For a full list of what your options are, please check [Apple's System-Declared UTI](https://developer.apple.com/library/content/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259-SW1).

As with all extensions, the flow of events is expected to be handled by a small app, external to your Cordova App but bundled with it. When installing the plugin, we will add a new target called **ShareExtension** to your XCode project which implements this Extension App. The Extension and the Cordova App live in different processes and can only communicate with each other using inter-app communication methods.

When a user posts some content using the Share Extension, the content will be stored in a Shared User-Preferences Container. To enable this, the Cordova App and Share Extension should define a group and add both the app and extension to it, manually. At the moment, it seems like it's not possible to automate the process. You can read more about this [here](http://www.atomicbird.com/blog/sharing-with-app-extensions).

Once the data is in place in the Shared User-Preferences Container, the Share Extension will open the Cordova App by calling a [Custom URL Scheme](https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html#//apple_ref/doc/uid/TP40007072-CH6-SW1). This seems a little borderline as Apple tries hard to prevent this from being possible, but brave iOS developers always find [solutions](https://stackoverflow.com/questions/24297273/openurl-not-work-in-action-extension/24614589#24614589)... So as for now there is one and it seems like people got their app pass the review process with it. At the moment of writing, this method is still working on iOS 11.1. The recommended solution is be to implement the posting logic in the Share Extension, but this doesn't play well with Cordova Apps architecture...

On the Cordova App side, the plugin checks listens for app start or resume events. When this happens, it looks into the Shared User-Preferences Container for any content to share and report it to the javascript application.

## Installation

Here's the promised one liner:

```
cordova plugin add cordova-plugin-openwith-ios --variable IOS_URL_SCHEME=cordovaopenwithdemo
```

| variable | example | notes |
|---|---|---|
| `IOS_URL_SCHEME` | uniquelonglowercase | Any random long string of lowercase alphabetical characters |

It shouldn't be too hard. But just in case, Jean-Christophe Hoelt [posted a screencast of it](https://youtu.be/eaE4m_xO1mg).

### iOS Setup

After having installed the plugin, with the ios platform in place, 1 operation needs to be done manually: setup the App Group on both the Cordova App and the Share Extension.

 1. open the **xcodeproject** for your application
 1. select the root element of your **project navigator** (the left-side pane)
 1. select the **target** of your main application
 1. select **Signing & Capabilities**
 1. click on **+ Capablity** in left top corner
 1. double-click on **App Groups** in the shown pop-up
 1. create and activate an **App Group** called: `group.<YOUR_APP_BUNDLE_ID>.shareextension`. You can check the required name 
 of the bundle in `platforms/ios/ShareExtension/ShareViewController.h` (SHAREEXT_GROUP_IDENTIFIER)
 1. repeat the previous steps for the **ShareExtension target**.
 1. **make sure that both main app and sharing extension have the same iOS version as deployment target**. 
 Check the General tab -> Deployment info and select the same iOS version for the both targets. 
 This is a necessary step, otherwise the application will not show up in sharing targets.
 1. just in case, check if the main app and extension have different bundle identifiers. If so, made them unique by adding .shareextension suffix to the latter
 1. check the troubleshooting section below if you faced any issues, including signing issues

You might also have to select a Team for both the App and Share Extension targets, make sure to select the same.

Build, XCode might complain about a few things to setup that it will fix for you (creation entitlements files, etc).

## Usage

```js
document.addEventListener('deviceready', setupOpenwith, false);

function setupOpenwith() {

  // Increase verbosity if you need more logs
  //cordova.openwith.setVerbosity(cordova.openwith.DEBUG);

  // Initialize the plugin
  cordova.openwith.init(initSuccess, initError);

  function initSuccess()  { console.log('init success!'); }
  function initError(err) { console.log('init failed: ' + err); }

  // Define your file handler
  cordova.openwith.addHandler(myHandler);

  function myHandler(intent) {
    console.log('intent received');
    console.log('  text: ' + intent.text); // description to the sharing, for instance title of the page when shared URL from Safari
    for (var i = 0; i < intent.items.length; ++i) {
      var item = intent.items[i];
      console.log('  type: ', item.uti);    // UTI. possible values: public.url, public.text or public.image
      console.log('  type: ', item.type);   // Mime type. For example: "image/jpeg"
      console.log('  data: ', item.data);   // shared data. For URLs and text - actually the shared URL or text. For image - its base64 string representation.
      console.log('  text: ', item.text);   // text to share alongside the item. as we don't allow user to enter text in native UI, in most cases this will be empty. However for sharing pages from Safari this might contain the title of the shared page.
      console.log('  name: ', item.name);   // suggested name of the image. For instance: "IMG_0404.JPG"
      console.log('  utis: ', item.utis);   // some optional additional info
    }
    // ...
    // Here, you probably want to do something useful with the data
    // ...
  }
}
```

### Controlling sharing file types

You can manually control which file types you app should accept. For this, you have to edit `platforms/ios/ShareExtension/ShareExtension-Info.plist`
 after plugin's installation. Scroll down to `NSExtensionActivationRule` <key> tag and take a look on the <dict> tag below.
 It contains the following keys:
 
 * `NSExtensionActivationSupportsAttachmentsWithMaxCount` {Integer} - The maximum number of attachments that the app extension supports.
 * `NSExtensionActivationSupportsAttachmentsWithMinCount` {Integer} - The minimum number of attachments that the app extension supports. 
 Set both parameters to 1 if you want to take only one file per share.  
 * `NSExtensionActivationSupportsFileWithMaxCount` {Integer} - The maximum number of all types of files that the app extension supports.
 * `NSExtensionActivationSupportsImageWithMaxCount` {Integer} - The maximum number of image files that the app extension supports. 
 Remove this key if you do not want to accept images.
 * `NSExtensionActivationSupportsMovieWithMaxCount` {Integer} - The maximum number of movie files that the app extension supports. 
 Remove this key if you do not want to accept video files.
 * `NSExtensionActivationSupportsText` {Integer} - A Boolean value indicating whether the app extension supports text.
 * `NSExtensionActivationSupportsWebURLWithMaxCount` {Integer} - The maximum number of HTTP URLs that the app extension supports. 
 Remove this key if you do not want to accept URLs (e.g. coming from Safari share button).
 
 You can also conveniently edit these preferences in Xcode visual editor by clicking on ShareExtension -> ShareExtension-Info.plist in the file navigator.
 
## API

### cordova.openwith.setVerbosity(level)

Change the verbosity level of the plugin.

`level` can be set to:

 - `cordova.openwith.DEBUG` for maximal verbosity, log everything.
 - `cordova.openwith.INFO` for the default verbosity, log interesting stuff only.
 - `cordova.openwith.WARN` for low verbosity, log only warnings and errors.
 - `cordova.openwith.ERROR` for minimal verbosity, log only errors.
 
### cordova.openwith.addHandler(handlerFunction)

Add an handler function, that will get notified when a file is received.

**Handler function**

The signature for the handler function is `function handlerFunction(intent)`. See below for what an intent is.

**Intent**

`intent` describe the operation to perform, toghether with the associated data. It has the following fields:

 - `text`: text to share alongside the item, in most cases this will be an empty string.
 - `items`: an array containing one or more data descriptor.

**Data descriptor**

A data descriptor describe one file. It is a javascript object with the following fields:

 - `uti`: Unique Type Identifier. possible values: public.url, public.text or public.image
 - `type`: Mime type. For example: "image/jpeg"
 - `text`: test description of the share, generally empty
 - `name`: suggested file name
 - `utis`: list of UTIs the file belongs to.

### cordova.openwith.load(dataDescriptor, loadSuccessCallback, loadErrorCallback)

Load data for an item. For this modification, it is not necessary, 

### cordova.openwith.exit()

Attempt to return the the calling app when sharing is done. Your app will be backgrounded,
it should be able to finish the upload.

Unfortunately, this is not working on iOS. The user can still select the
"Back-to-app" button visible on the top left. Make sure your UI shows the user
that he can now safely go back to what he was doing.

## Troubleshooting

Issue: I cannot see my app in share targets

Solution: Check that the both main app and sharing extension have the same iOS version in deploying target (see General -> Deployment info tab in Xcode)

Issue: I get conflicting provisioning settings error when I try to archive to submit an iOS app

Solution: Uncheck "Automatically manage signing", then check it again and reselect the Team. Xcode then fixed whatever was causing the issue on its own

Issue: Physical iPhone device complains on untrusted developer issues

Solution: Open Settings -> General -> Profiles & Device Management. Tap on your app in Developer App section, push on the trust button and confirm the modal.

## Contribute

Contributions in the form of GitHub pull requests are welcome. Please adhere to the following guidelines:
  - Before embarking on a significant change, please create an issue to discuss the proposed change and ensure that it is likely to be merged.
  - Follow the coding conventions used throughout the project. Many conventions are enforced using eslint and pmd. Run `npm t` to make sure of that.
  - Any contributions must be licensed under the MIT license.

## License

[MIT](./LICENSE)

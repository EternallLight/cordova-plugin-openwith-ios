//
//  ShareViewController.m
//  OpenWith - Share Extension
//

//
// The MIT License (MIT)
//
// Copyright (c) 2017 Jean-Christophe Hoelt
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <UIKit/UIKit.h>
#import <Social/Social.h>
#import "ShareViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

/*
 * Add base64 export to NSData
 */
@interface NSData (Base64)
- (NSString*)convertToBase64;
@end

@implementation NSData (Base64)
- (NSString*)convertToBase64 {
    const uint8_t* input = (const uint8_t*)[self bytes];
    NSInteger length = [self length];

    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;

    NSInteger i;
    for (i=0; i < length; i += 3) {
        NSInteger value = 0;
        NSInteger j;
        for (j = i; j < (i + 3); j++) {
            value <<= 8;

            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }

        NSInteger theIndex = (i / 3) * 4;
        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }

    NSString *ret = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
#if ARC_DISABLED
    [ret autorelease];
#endif
    return ret;
}
@end

@interface ShareViewController : SLComposeServiceViewController <UIAlertViewDelegate> {
    int _verbosityLevel;
    NSUserDefaults *_userDefaults;
    NSString *_backURL;

    //- (void)sendResults
}
@property (nonatomic) int verbosityLevel;
@property (nonatomic,retain) NSUserDefaults *userDefaults;
@property (nonatomic,retain) NSString *backURL;
@end

/*
 * Constants
 */

#define VERBOSITY_DEBUG  0
#define VERBOSITY_INFO  10
#define VERBOSITY_WARN  20
#define VERBOSITY_ERROR 30

@implementation ShareViewController

@synthesize verbosityLevel = _verbosityLevel;
@synthesize userDefaults = _userDefaults;
@synthesize backURL = _backURL;

- (void) log:(int)level message:(NSString*)message {
    if (level >= self.verbosityLevel) {
        NSLog(@"[ShareViewController.m]%@", message);
    }
}
- (void) debug:(NSString*)message { [self log:VERBOSITY_DEBUG message:message]; }
- (void) info:(NSString*)message { [self log:VERBOSITY_INFO message:message]; }
- (void) warn:(NSString*)message { [self log:VERBOSITY_WARN message:message]; }
- (void) error:(NSString*)message { [self log:VERBOSITY_ERROR message:message]; }

- (void) setup {
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:SHAREEXT_GROUP_IDENTIFIER];
    self.verbosityLevel = [self.userDefaults integerForKey:@"verbosityLevel"];
    [self debug:@"[setup]"];
}

- (BOOL) isContentValid {
    return YES;
}

- (void) openURL:(nonnull NSURL *)url {

    SEL selector = NSSelectorFromString(@"openURL:options:completionHandler:");

    UIResponder* responder = self;
    while ((responder = [responder nextResponder]) != nil) {
        NSLog(@"responder = %@", responder);
        if([responder respondsToSelector:selector] == true) {
            NSMethodSignature *methodSignature = [responder methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];

            // Arguments
            NSDictionary<NSString *, id> *options = [NSDictionary dictionary];
            void (^completion)(BOOL success) = ^void(BOOL success) {
                NSLog(@"Completions block: %i", success);
            };

            [invocation setTarget: responder];
            [invocation setSelector: selector];
            [invocation setArgument: &url atIndex: 2];
            [invocation setArgument: &options atIndex:3];
            [invocation setArgument: &completion atIndex: 4];
            [invocation invoke];
            break;
        }
    }
}
- (void) viewDidAppear:(BOOL)animated {
    [self.view endEditing:YES];
}

- (void) viewDidLoad {
    [self setup];
    [self debug:@"[viewDidLoad]"];

    BOOL isLoggedIn = [self.userDefaults boolForKey:@"loggedIn"];

    if (!isLoggedIn) {

        NSString *alertTitle = NSLocalizedString(@"Sharing error", @"Sharing error alert title");
        NSString *alertMessage = NSLocalizedString(@"You have to be logged in in order to share items.", @"Sharing error alert message");

        UIAlertController *alert = [UIAlertController
                                     alertControllerWithTitle: alertTitle
                                     message: alertMessage
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okButton = [UIAlertAction
                                    actionWithTitle:@"OK"
                                    style:UIAlertActionStyleDefault
                                    handler: ^(UIAlertAction * action) {
                                       // Shut down the extension when the OK button clicked.
                                       [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
                                    }];
        [alert addAction:okButton];

        [self presentViewController:alert animated:YES completion: nil];
        return;
    }

    __block int remainingAttachments = ((NSExtensionItem*)self.extensionContext.inputItems[0]).attachments.count;
    __block NSMutableArray *items = [[NSMutableArray alloc] init];
    __block NSDictionary *results = @{
                                          @"text" : self.contentText,
                                          @"backURL": self.backURL != nil ? self.backURL : @"",
                                          @"items": items,
                                      };

    for (NSItemProvider* itemProvider in ((NSExtensionItem*)self.extensionContext.inputItems[0]).attachments) {
        [self debug:[NSString stringWithFormat:@"item provider registered indentifiers = %@", itemProvider.registeredTypeIdentifiers]];
        // URL case
        if ([itemProvider hasItemConformingToTypeIdentifier:@"public.url"]) {
            [itemProvider loadItemForTypeIdentifier:@"public.url" options:nil completionHandler: ^(NSURL* item, NSError *error) {
                --remainingAttachments;
                [self debug:[NSString stringWithFormat:@"public.url = %@", item]];
                NSString *uti = @"public.url";
                NSDictionary *dict = @{

                                           @"data" : item.absoluteString,
                                           @"uti": uti,
                                           @"utis": itemProvider.registeredTypeIdentifiers,
                                           @"name": @"",
                                           @"type": [self mimeTypeFromUti:uti],
                                      };
                [items addObject:dict];
                if (remainingAttachments == 0) {
                    [self sendResults:results];
                }
            }];
        }
        // TEXT case
        else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.text"]) {
            [itemProvider loadItemForTypeIdentifier:@"public.text" options:nil completionHandler: ^(NSString* item, NSError *error) {
                --remainingAttachments;
                [self debug:[NSString stringWithFormat:@"public.text = %@", item]];
                NSString *uti = @"public.text";
                NSDictionary *dict = @{
                                           @"text" : self.contentText,
                                           @"data" : item,
                                           @"uti": uti,
                                           @"utis": itemProvider.registeredTypeIdentifiers,
                                           @"name": @"",
                                           @"type": [self mimeTypeFromUti:uti],
                                       };
                [items addObject:dict];
                if (remainingAttachments == 0) {
                    [self sendResults:results];
                }
            }];
        }
        // IMAGE case
        else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];

            [itemProvider loadItemForTypeIdentifier:@"public.image" options:nil completionHandler: ^(NSURL* item, NSError *error) {
                --remainingAttachments;
                NSData *data = [NSData dataWithContentsOfURL:(NSURL*)item];
                NSString *base64 = [data convertToBase64];
                NSString *suggestedName = item.lastPathComponent;

                NSString *uti = @"public.image";

                NSString *registeredType = nil;
                if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                    registeredType = itemProvider.registeredTypeIdentifiers[0];
                } else {
                    registeredType = uti;
                }

                NSString *mimeType =  [self mimeTypeFromUti:registeredType];

                NSDictionary *dict = @{
                                           @"text" : self.contentText,
                                           @"data" : base64,
                                           @"uti"  : uti,
                                           @"utis" : itemProvider.registeredTypeIdentifiers,
                                           @"name" : suggestedName,
                                           @"type" : mimeType
                                      };

                [items addObject:dict];
                if (remainingAttachments == 0) {
                    [self sendResults:results];
                }
            }];
        }
        else {
            [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
        }
    }
}

- (void) sendResults: (NSDictionary*)results {
    [self.userDefaults setObject:results forKey:@"shared"];
    [self.userDefaults synchronize];

    // Emit a URL that opens the cordova app
    NSString *url = [NSString stringWithFormat:@"%@://shared", SHAREEXT_URL_SCHEME];

    [self openURL:[NSURL URLWithString:url]];

    // Shut down the extension
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

 - (void) didSelectPost {
     [self debug:@"[didSelectPost]"];
 }

- (NSArray*) configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return @[];
}

- (NSString*) backURLFromBundleID: (NSString*)bundleId {
    if (bundleId == nil) return nil;
    // App Store - com.apple.AppStore
    if ([bundleId isEqualToString:@"com.apple.AppStore"]) return @"itms-apps://";
    // Calculator - com.apple.calculator
    // Calendar - com.apple.mobilecal
    // Camera - com.apple.camera
    // Clock - com.apple.mobiletimer
    // Compass - com.apple.compass
    // Contacts - com.apple.MobileAddressBook
    // FaceTime - com.apple.facetime
    // Find Friends - com.apple.mobileme.fmf1
    // Find iPhone - com.apple.mobileme.fmip1
    // Game Center - com.apple.gamecenter
    // Health - com.apple.Health
    // iBooks - com.apple.iBooks
    // iTunes Store - com.apple.MobileStore
    // Mail - com.apple.mobilemail - message://
    if ([bundleId isEqualToString:@"com.apple.mobilemail"]) return @"message://";
    // Maps - com.apple.Maps - maps://
    if ([bundleId isEqualToString:@"com.apple.Maps"]) return @"maps://";
    // Messages - com.apple.MobileSMS
    // Music - com.apple.Music
    // News - com.apple.news - applenews://
    if ([bundleId isEqualToString:@"com.apple.news"]) return @"applenews://";
    // Notes - com.apple.mobilenotes - mobilenotes://
    if ([bundleId isEqualToString:@"com.apple.mobilenotes"]) return @"mobilenotes://";
    // Phone - com.apple.mobilephone
    // Photos - com.apple.mobileslideshow
    if ([bundleId isEqualToString:@"com.apple.mobileslideshow"]) return @"photos-redirect://";
    // Podcasts - com.apple.podcasts
    // Reminders - com.apple.reminders - x-apple-reminder://
    if ([bundleId isEqualToString:@"com.apple.reminders"]) return @"x-apple-reminder://";
    // Safari - com.apple.mobilesafari
    // Settings - com.apple.Preferences
    // Stocks - com.apple.stocks
    // Tips - com.apple.tips
    // Videos - com.apple.videos - videos://
    if ([bundleId isEqualToString:@"com.apple.videos"]) return @"videos://";
    // Voice Memos - com.apple.VoiceMemos - voicememos://
    if ([bundleId isEqualToString:@"com.apple.VoiceMemos"]) return @"voicememos://";
    // Wallet - com.apple.Passbook
    // Watch - com.apple.Bridge
    // Weather - com.apple.weather
    return nil;
}

// This is called at the point where the Post dialog is about to be shown.
// We use it to store the _hostBundleID
- (void) willMoveToParentViewController: (UIViewController*)parent {
    NSString *hostBundleID = [parent valueForKey:(@"_hostBundleID")];
    self.backURL = [self backURLFromBundleID:hostBundleID];
}


- (NSString *)mimeTypeFromUti: (NSString*)uti {
    if (uti == nil) {
        return nil;
    }
    CFStringRef cret = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)uti, kUTTagClassMIMEType);
    NSString *ret = (__bridge_transfer NSString *)cret;
    return ret == nil ? uti : ret;
}

@end

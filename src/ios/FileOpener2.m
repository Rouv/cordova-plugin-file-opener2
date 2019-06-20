/*
The MIT License (MIT)

Copyright (c) 2013 pwlin - pwlin05@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
#import "FileOpener2.h"
#import <Cordova/CDV.h>

#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/MobileCoreServices.h>

@implementation FileOpener2
@synthesize controller = docController;

- (UIViewController*) getTopMostViewController
{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if (window.windowLevel != UIWindowLevelNormal) {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(window in windows) {
            if (window.windowLevel == UIWindowLevelNormal) {
                break;
            }
        }
    }
    
    for (UIView *subView in [window subviews])
    {
        UIResponder *responder = [subView nextResponder];
        
        //added this block of code for iOS 8 which puts a UITransitionView in between the UIWindow and the UILayoutContainerView
        if ([responder isEqual:window])
        {
            //this is a UITransitionView
            if ([[subView subviews] count])
            {
                UIView *subSubView = [subView subviews][0]; //this should be the UILayoutContainerView
                responder = [subSubView nextResponder];
            }
        }
        
        if([responder isKindOfClass:[UIViewController class]]) {
            return [self topViewController: (UIViewController *) responder];
        }
    }
    
    return nil;
}


- (UIViewController *) topViewController: (UIViewController *) controller
{
    BOOL isPresenting = NO;
    do {
        // this path is called only on iOS 6+, so -presentedViewController is fine here.
        UIViewController *presented = [controller presentedViewController];
        isPresenting = presented != nil;
        if(presented != nil) {
            controller = presented;
        }
        
    } while (isPresenting);
    
    return controller;
}
- (void) open: (CDVInvokedUrlCommand*)command {

	NSString *path = [[command.arguments objectAtIndex:0] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
	NSString *contentType = [command.arguments objectAtIndex:1];
	BOOL showPreview = NO;

	if ([command.arguments count] >= 3) {
		showPreview = [[command.arguments objectAtIndex:2] boolValue];
	}

	CDVViewController* cont = (CDVViewController*)[super viewController];
	self.cdvViewController = cont;
	NSString *uti = nil;

	if([contentType length] == 0){
		NSArray *dotParts = [path componentsSeparatedByString:@"."];
		NSString *fileExt = [dotParts lastObject];

		uti = (__bridge NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExt, NULL);
	} else {
		uti = (__bridge NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)contentType, NULL);
	}
NSLog(@"uti %@", uti);
	dispatch_async(dispatch_get_main_queue(), ^{
		NSURL *fileURL = [NSURL URLWithString:[path stringByRemovingPercentEncoding]];

		localFile = fileURL.path;

	    NSLog(@"looking for file at %@", fileURL);
	    NSFileManager *fm = [NSFileManager defaultManager];
	    if(![fm fileExistsAtPath:localFile]) {
	    	NSDictionary *jsonObj = @{@"status" : @"9",
	    	@"message" : @"File does not exist"};
	    	CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:jsonObj];
	      	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
	      	return;
    	}

		docController = [UIDocumentInteractionController  interactionControllerWithURL:fileURL];
		docController.delegate = self;
		docController.UTI = uti;

		CDVPluginResult* pluginResult = nil;

		//Opens the file preview
		BOOL wasOpened = NO;

		if (showPreview) {
			wasOpened = [docController presentPreviewAnimated: NO];
		} else {
            UIWindow *topWindow = [[[UIApplication sharedApplication].windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *win1, UIWindow *win2) {
                return win1.windowLevel - win2.windowLevel;
            }] lastObject];
            UIView *topView = [[topWindow subviews] lastObject];
            UIViewController *viewCtrl = [self getTopMostViewController];
			//CDVViewController* cont = self.cdvViewController;

			CGRect rect = CGRectMake(0, 0, viewCtrl.view.bounds.size.width, viewCtrl.view.bounds.size.height);
			wasOpened = [docController presentOpenInMenuFromRect:rect inView:viewCtrl.view animated:NO];
		}

		if(wasOpened) {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: @""];
			//NSLog(@"Success");
		} else {
			NSDictionary *jsonObj = [ [NSDictionary alloc]
				initWithObjectsAndKeys :
				@"9", @"status",
				@"Could not handle UTI", @"message",
				nil
			];
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:jsonObj];
		}
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
	});
}

@end

@implementation FileOpener2 (UIDocumentInteractionControllerDelegate)
	- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
		UIViewController *presentingViewController = self.viewController;
		if (presentingViewController.view.window != [UIApplication sharedApplication].keyWindow){
			presentingViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
		}

		while (presentingViewController.presentedViewController != nil && ![presentingViewController.presentedViewController isBeingDismissed]){
			presentingViewController = presentingViewController.presentedViewController;
		}
		return presentingViewController;
	}
@end

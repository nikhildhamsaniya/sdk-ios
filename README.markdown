  **NOTE: THIS IS A DEVELOPMENT BRANCH!** which may have code that is not fully supported by our APIs or documentation. Please use one of our tagged releases instead. 
PlayHaven SDK
==============
The PlayHaven Content SDK allows you to add dynamic content to your app. It is a flexible framework capable of delivering integrated experiences; including ads, special offers, announcements and other kinds of content which can be dynamically assigned to placements within your application.

An API token and secret pair is required to use this SDK. These tokens identify your app to PlayHaven and prevent others from making requests to the API on your behalf. To obtain these credentials for your application please visit http://playhaven.com and log into the Developer Dashboard.

Integration
-----------
1. Add the following from the sdk-ios directory that you downloaded or cloned from github to your project:
  * src directory  
  * PlayHaven.bundle
  * JSON directory (unless you are already using SBJSON in your project)
1. Ensure the following frameworks are included with your project, add any missing frameworks in the Build Phases tab for your application's target:
  * UIKit.framework
  * Foundation.framework
  * CoreGraphics.framework
  * QuartzCore.framework
1. Include the PlayHavenSDK headers in your code wherever you will be using PlayHaven request classes.

> \#import "PlayHavenSDK.h"

Example App
-----------
Included with the SDK is an example implementation in its own XCode project. It features open and content request implementations including relevant delegate methods for each. To run the example app, you will need to define the preprocessor macros found in *example/Constants.h".

API Reference
-------------
### Recording game opens
In order to better optimize your campaigns, it is necessary for your app to report all game opens. This will allow us to calculate impression rates based on all game opens. A delegate is not needed for this request, but if you would like to recieve a callback when this request succeeds or fails refer to the implementation found in *example/PublisherOpenViewController.m*.

> [[PHPublisherOpenRequest requestForApp:(NSString *)token secret:(NSString *)secret] send]

### Requesting content for your placements
You may request content for your app using your API token, secret, as well as a placement_id to identify the placement you are requesting content for. Implement PHPublisherContentRequestDelegate methods to recieve callbacks from this request. Refer to the section below as well as *example/PublisherContentViewController.m* for a sample implementation.

> [[PHPublisherContentRequest requestForApp:(NSString *)token secret:(NSString *)secret placement:(NSString *)placement delegate:(id)delegate] send]

*NOTE:* Currently the only valid placement is *"more_games"*.

#### Starting a content request
The request is about to attempt to get content from the PlayHaven API. 

> \-(void)requestWillGetContent:(PHPublisherContentRequest *)request;

#### Preparing to show a content view
If there is content for this placement, it will be loaded at this point. An overlay view will appear over your app and a spinner will indicate that the content is loading. Depending on the transition type for your content your view may or may not be visible at this time. If you haven't before, you should mute any sounds and pause any animations in your app. 

> \-(void)request:(PHPublisherContentRequest *)request contentWillDisplay:(PHContent *)content;

#### Content view finished loading
The content has been successfully loaded and the user is now interacting with the downloaded content view. 

> \-(void)request:(PHPublisherContentRequest *)request contentDidDisplay:(PHContent *)content;

#### Content view dismissing
The content has successfully dismissed and control is being returned to your app. This can happen as a result of the user clicking on the close button or clicking on a link that will open outside of the app. You may restore sounds and animations at this point.

> \-(void)requestContentDidDismiss:(PHPublisherContentRequest *)request;

#### Content request failing
If for any reason the content request does not successfully return some content to display, the request will stop. At this point, no visible changes have occurred in your app.

> \-(void)request:(PHPublisherContentRequest *)request didFailWithError:(NSError *)error;

#### Content view failing to load
If for any reason a content unit fails to load after the overlay view has appeared, the request will stop and the overlay view will be removed. You may restore sounds and animations at this point.

> \-(void)request:(PHPublisherContentRequest *)request contentDidFailWithError:(NSError *)error;

### Customizing content display
#### Replace close button graphics
Use the following request method to replace the close button image with something that more closely matches your app. Images will be resized to 40x40.

> \-(UIImage *)request:(PHPublisherContentRequest *)request closeButtonImageForControlState:(UIControlState)state content:(PHContent *)content;

### Notifications with PHNotificationView
PHNotificationView provides a fully encapsulated notification view that automatically fetches an appropriate notification from the API and renders it into your view heirarchy. It is a UIView subclass that you may place in your UI where it should appear and supply it with your app token, secret, and a placement id.

> \-(id)initWithApp:(NSString *)app secret:(NSString *)secret placement:(NSString *)placement;

*NOTE:* Currently the only valid placement is *"more_games"*.

Notification view will remain anchored to the center of the position they are placed in the view, even as the size of the badge changes. You may refresh your notification view from the network using the -(void)refresh method on an instance. We recommend refreshing the notification view each time it will appear in your UI. See *examples/PublisherContentViewController.m* for an example.

You will also need to clear any notification view instances when you successfully launch a content unit. You may do this using the -(void)clear method on any notification views you wish to clear. (See *Preparing to show a content view*, above.)

### Testing PHNotificationView
Defining the PH_TEST_MODE preprocessor macro will enable test mode on all PHNotificationView instances. In this mode, each PHNotificationView will show a red dot badge notification on -(void)refresh. You may set this macro in your app's Build Settings.

![Example.app's XCode Build Settings](http://media.playhaven.com/github/phtestmode-setting.jpg "Build Settings enabling test mode in Example.app's Debug configuration")

### Customizing notification rendering with PHNotificationRenderer
PHNotificationRenderer is a base class that draws a notification view for a given notification data. The base class implements a blank notification view used for unknown notification types. PHNotificationBadgeRenderer renders a iOS default-style notification badge with a given "value" string. You may customize existing notification renderers and register new ones at runtime using the following method on PHNotificationView

> \+(void)setRendererClass:(Class)class forType:(NSString *)type;

Your PHNotificationRenderer subclass needs to implement the following methods to draw and size your notification view appropriately:

> \-(void)drawNotification:(NSDictionary *)notificationData inRect:(CGRect)rect;

This method will be called inside of the PHNotificationView instance -(void)drawRect: method whenever the view needs to be drawn. You will use specific keys inside of notificationData to draw your badge in the view. If you need access to the graphics context you may use the UIGraphicsGetCurrentContext() function.

> \-(CGSize)sizeForNotification:(NSDictionary *)notificationData;

This method will be called to calculate an appropriate frame for the notification badge each time the notification data changes. Using specific keys inside of notificationData, you will need to calculate an appropriate size.


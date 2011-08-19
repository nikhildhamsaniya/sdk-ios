//
//  PHContentView.m (formerly PHAdUnitView.m)
//  playhaven-sdk-ios
//
//  Created by Jesus Fernandez on 4/1/11.
//  Copyright 2011 Playhaven. All rights reserved.
//

#import "PHContentView.h"
#import "PHContent.h"
#import "PHContentWebView.h"
#import "PHURLLoaderView.h"
#import "NSObject+QueryComponents.h"
#import "JSON.h"
#import "PHConstants.h"

#define MAX_MARGIN 20

@interface PHContentView(Private)
- (void)sizeToFitOrientation:(BOOL)transform;
-(CGAffineTransform)transformForOrientation:(UIInterfaceOrientation)orientation;
-(void)orientationDidChange;
-(void)viewDidShow;
-(void)viewDidDismiss;
-(void)dismissView;
-(void)handleLaunch:(NSDictionary *)queryComponents;
-(void)handleDismiss:(NSDictionary *)queryComponents;
-(void)handleLoadContext:(NSDictionary *)queryComponents callback:(NSString*)callback;
-(UIActivityIndicatorView *)activityView;
-(void)didBounceInWebView;
-(void)showCloseButton;
-(void)hideCloseButton;
-(void)dismissWithError:(NSError *)error;
@end

@implementation PHContentView

-(id) initWithContent:(PHContent *)content{
  if ((self = [super initWithFrame:[[UIScreen mainScreen] applicationFrame]])) {
    
    NSInvocation
    *dismissRedirect = [NSInvocation invocationWithMethodSignature:[[self class] instanceMethodSignatureForSelector:@selector(handleDismiss:)]],
    *launchRedirect = [NSInvocation invocationWithMethodSignature:[[self class] instanceMethodSignatureForSelector:@selector(handleLaunch:)]],
    *loadContextRedirect = [NSInvocation invocationWithMethodSignature:[[self class] instanceMethodSignatureForSelector:@selector(handleLoadContext:callback:)]];
    
    dismissRedirect.target = self;
    dismissRedirect.selector = @selector(handleDismiss:);
    
    launchRedirect.target = self;
    launchRedirect.selector = @selector(handleLaunch:);
    
    loadContextRedirect.target = self;
    loadContextRedirect.selector = @selector(handleLoadContext:callback:);
    
    _redirects = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                  dismissRedirect,@"ph://dismiss",
                  launchRedirect,@"ph://launch",
                  loadContextRedirect,@"ph://loadContext",
                  nil];
    
    _content = [content retain];
    
    
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    _targetView = window;
    
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
  }
  
  return self;
}

@synthesize content = _content;
@synthesize delegate = _delegate;
@synthesize targetView = _targetView;

-(UIActivityIndicatorView *)activityView{
  if (_activityView == nil){
    _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _activityView.hidesWhenStopped = YES;
    [_activityView startAnimating];
  }
  
  return _activityView;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_content release], _content = nil;
  [_webView release], _webView = nil;
  [_redirects release], _redirects = nil;
  [_activityView release] , _activityView = nil;
  [_closeButton release], _closeButton = nil;
  [super dealloc];
}

-(void) orientationDidChange{
  UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
  if (orientation != _orientation) {
    if (CGRectIsNull([self.content frameForOrientation:orientation])) {
      //this is an invalid frame and we should dismiss immediately!
      NSError *error = [NSError errorWithDomain:@"PHOrientation" code:500 userInfo:nil];
      [self dismissWithError:error];
      return;
    }

    CGFloat duration = [UIApplication sharedApplication].statusBarOrientationAnimationDuration;
    
    if (self.content.transition == PHContentTransitionDialog) {
      CGFloat barHeight = ([[UIApplication sharedApplication] isStatusBarHidden])? 0 : 20;
      CGRect contentFrame = CGRectOffset([self.content frameForOrientation:orientation], 0, barHeight);
      _webView.frame = contentFrame;
      
      [self sizeToFitOrientation:YES];
      [self hideCloseButton];
    }
    
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:duration];
    //[UIView setAnimationDelegate:self];
    //[UIView setAnimationDidStopSelector:@selector(showCloseButton)];
    if (self.content.transition == PHContentTransitionDialog) {
      _webView.transform = CGAffineTransformIdentity;
    } else{
      [self sizeToFitOrientation:YES];
    }
    [UIView commitAnimations];
  }
}

- (void)sizeToFitOrientation:(BOOL)transform {
  if (transform) {
    self.transform = CGAffineTransformIdentity;
  }
  
  CGRect frame = [UIScreen mainScreen].bounds;
  CGPoint center = CGPointMake(
                               frame.origin.x + ceilf(frame.size.width/2),
                               frame.origin.y + ceilf(frame.size.height/2));
  
  CGFloat scale_factor = 1.0f;
  
  CGFloat width = floorf(scale_factor * frame.size.width);
  CGFloat height = floorf(scale_factor * frame.size.height);
  
  _orientation = [UIApplication sharedApplication].statusBarOrientation;
  if (UIInterfaceOrientationIsLandscape(_orientation)) {
    self.frame = CGRectMake(0, 0, height, width);
  } else {
    self.frame = CGRectMake(0, 0, width, height);
  }
  self.center = center;
  
  if (transform) {
    self.transform = [self transformForOrientation:_orientation];
  }
}

-(CGAffineTransform) transformForOrientation:(UIInterfaceOrientation)orientation{
  if (orientation == UIInterfaceOrientationLandscapeLeft) {
    return CGAffineTransformMakeRotation((float)-M_PI/2);
  } else if (orientation == UIInterfaceOrientationLandscapeRight) {
    return CGAffineTransformMakeRotation((float)M_PI/2);
  } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
    return CGAffineTransformMakeRotation((float)-M_PI);
  } else {
    return CGAffineTransformIdentity;
  }
}

-(void) show:(BOOL)animated{
  
  _willAnimate = animated;
  [self.targetView addSubview: self];
  [self sizeToFitOrientation:YES];

  
  if (CGRectIsNull([self.content frameForOrientation:_orientation])) {
    //this is an invalid frame and we should dismiss immediately!
    NSError *error = [NSError errorWithDomain:@"PHOrientation" code:500 userInfo:nil];
    [self dismissWithError:error];
    return;
  }
  
  CGFloat barHeight = ([[UIApplication sharedApplication] isStatusBarHidden])? 0 : 20;
  
  if (self.content.transition == PHContentTransitionModal) {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    
    CGFloat width, height;
    if (UIInterfaceOrientationIsPortrait(_orientation)) {
      width = self.frame.size.width;
      height = self.frame.size.height;
    } else {
      width = self.frame.size.height;
      height = self.frame.size.width;
    }
    
    _webView = [[PHContentWebView alloc] initWithFrame:CGRectMake(0, barHeight, width, height-barHeight)];
    _webView.delegate = self;
    _webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _webView.layer.borderWidth = 0.0f;
    
    [self addSubview:_webView];
    
    [self activityView].center = _webView.center;
    
    if (animated) {
      CGAffineTransform oldTransform = self.transform;
      self.transform = CGAffineTransformTranslate(oldTransform, 0, self.frame.size.height);
      [UIView beginAnimations:nil context:nil];
      [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
      [UIView setAnimationDuration:0.25];
      [UIView setAnimationDelegate:self];
      [UIView setAnimationDidStopSelector:@selector(viewDidShow)];
      self.transform = oldTransform;
      [UIView commitAnimations];
    } else {
      [self viewDidShow];
    }
  } else if (self.content.transition == PHContentTransitionDialog) {
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.1];
    self.opaque = NO;
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    CGRect contentFrame = CGRectOffset([self.content frameForOrientation:orientation], 0, barHeight);
    _webView = [[PHContentWebView alloc] initWithFrame:contentFrame];
    _webView.layer.borderColor = [[UIColor blackColor] CGColor];
    _webView.layer.borderWidth = 1.0f;
    
    
    if ([self.delegate respondsToSelector:@selector(borderColorForContentView:)]) {
      _webView.layer.borderColor = [[self.delegate borderColorForContentView:self] CGColor];
    }
    
    [_webView setDelegate:self];
    [self addSubview:_webView];
    
    [self activityView].center = _webView.center;
    
    [self viewDidShow];
    
    if (animated) {
      [_webView bounceInWithTarget:self action:@selector(didBounceInWebView)];
    }
  }
  
  [self addSubview:[self activityView]];
  
  //TRACK_ORIENTATION see STOP_TRACK_ORIENTATION
  [[NSNotificationCenter defaultCenter] 
   addObserver:self
   selector:@selector(orientationDidChange) 
   name:UIDeviceOrientationDidChangeNotification
   object:nil];
}

-(void) dismiss:(BOOL)animated{
  _willAnimate = animated;
  if (self.content.transition == PHContentTransitionModal) {
    if (animated) {
      CGAffineTransform oldTransform = self.transform;
      [UIView beginAnimations:nil context:nil];
      [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
      [UIView setAnimationDuration:0.25];
      [UIView setAnimationDelegate:self];
      [UIView setAnimationDidStopSelector:@selector(dismissView)];
      self.transform = CGAffineTransformTranslate(oldTransform, 0, self.frame.size.height);
      [UIView commitAnimations];
    } else {
      [self dismissView];
    }
  } else if (self.content.transition == PHContentTransitionDialog){
    if (animated) {
      [_webView bounceOutWithTarget:self action:@selector(dismissView)];
    } else {
      [self dismissView];
    }
  }
  
  //STOP_TRACK_ORIENTATION see TRACK_ORIENTATION
  [[NSNotificationCenter defaultCenter] 
   removeObserver:self 
   name:UIDeviceOrientationDidChangeNotification 
   object:nil];
}

-(void)dismissFromButton{
  NSDictionary *queryComponents = [NSDictionary dictionaryWithObjectsAndKeys:
                                   self.content.closeButtonURLPath, @"ping", nil];
  [self handleDismiss:queryComponents];
}

-(void)dismissView{
  [self removeFromSuperview];
  [_webView release], _webView = nil;
  
  [self viewDidDismiss];
}

-(void)dismissWithError:(NSError *)error{
  [self removeFromSuperview];
  [_webView release], _webView = nil;
  
  if ([self.delegate respondsToSelector:(@selector(contentView:didFailWithError:))]) {
    [self.delegate contentView:self didFailWithError:error];
  }
}

-(void) viewDidShow{
  [_webView loadRequest:[NSURLRequest requestWithURL:self.content.URL]];
  if ([self.delegate respondsToSelector:(@selector(contentViewDidShow:))]) {
    [self.delegate contentViewDidShow:self];
  }
}

-(void) viewDidDismiss{
  if ([self.delegate respondsToSelector:(@selector(contentViewDidDismiss:))]) {
    [self.delegate contentViewDidDismiss:self];
  }
}

#pragma mark -
#pragma mark UIWebViewDelegate
-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
  NSURL *url = request.URL;
  NSString *urlPath = [NSString stringWithFormat:@"%@://%@%@", [url scheme], [url host], [url path]];
  NSInvocation *redirect = [_redirects valueForKey:urlPath];
  if (redirect) {
    NSDictionary *queryComponents = [url queryComponents];
    NSString *callback = [queryComponents valueForKey:@"callback"];
    
    NSString *contextString = [queryComponents valueForKey:@"context"];
    NSDictionary *context = (!!contextString)?[contextString JSONValue]:nil;
    
    NSLog(@"[PHContentView] Redirecting request with callback: %@ to dispatch %@", callback, urlPath);
    switch ([[redirect methodSignature] numberOfArguments]) {
      case 5:
        [redirect setArgument:&self atIndex:4]; 
      case 4:
        if(!!callback) [redirect setArgument:&callback atIndex:3]; 
      case 3:
        if(!!context) [redirect setArgument:&context atIndex:2]; 
      default:
        break;
    }

    [redirect invoke];
    return NO;
  }
  
  return ![[url scheme] isEqualToString:@"ph"];
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
  [self dismissWithError:error];
}

-(void)webViewDidFinishLoad:(UIWebView *)webView{
  [[self activityView] stopAnimating]; 
  
  //update Webview with current PH_DISPATCH_PROTOCOL_VERSION
  NSString *loadCommand = [NSString stringWithFormat:@"window.PlayHavenDispatchProtocolVersion = %d", PH_DISPATCH_PROTOCOL_VERSION];
  [webView stringByEvaluatingJavaScriptFromString:loadCommand];
  
  if ([self.delegate respondsToSelector:(@selector(contentViewDidLoad:))]) {
    [self.delegate contentViewDidLoad:self];
  }
}

-(void)didBounceInWebView{
  //[self performSelector:@selector(showCloseButton) withObject:nil afterDelay:self.content.closeButtonDelay];
}

-(void)showCloseButton{
  if (self.content.transition == PHContentTransitionDialog) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCloseButton) object:nil];
    
    if (_closeButton == nil) {
      _closeButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
      _closeButton.frame = CGRectMake(0, 0, 40, 40);
      
      UIImage *closeImage = nil, *closeActiveImage = nil;
      if ([self.delegate respondsToSelector:@selector(contentView:imageForCloseButtonState:)]) {
        closeImage = [self.delegate contentView:self imageForCloseButtonState:UIControlStateNormal];
        closeActiveImage = [self.delegate contentView:self imageForCloseButtonState:UIControlStateHighlighted];
      }
      closeImage = (!closeImage)? [UIImage imageNamed:@"PlayHaven.bundle/images/close.png"] : closeImage;
      closeActiveImage = (!closeActiveImage)?[UIImage imageNamed:@"PlayHaven.bundle/images/close-active.png"]: closeActiveImage;
      
      [_closeButton setImage:closeImage forState:UIControlStateNormal];
      [_closeButton setImage:closeActiveImage forState:UIControlStateHighlighted];
      
      [_closeButton addTarget:self action:@selector(dismissFromButton) forControlEvents:UIControlEventTouchUpInside];
      
    }
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    CGFloat barHeight = ([[UIApplication sharedApplication] isStatusBarHidden])? 0 : 20;\
    CGRect contentFrame = CGRectOffset([self.content frameForOrientation:orientation], 0, barHeight);

    CGRect screen = [[UIScreen mainScreen] applicationFrame];
    CGFloat maxWidth = (UIInterfaceOrientationIsLandscape(orientation))? screen.size.height : screen.size.width;
    
    CGFloat
      x = CGRectGetMaxX(contentFrame),
      y = CGRectGetMinY(contentFrame),
      maxX = maxWidth - MAX_MARGIN,
      minY = MAX_MARGIN + barHeight;
    
    _closeButton.center = CGPointMake(MIN(x, maxX), MAX(y, minY));
    
    [self addSubview:_closeButton];

  }
}

-(void)hideCloseButton{
  [_closeButton removeFromSuperview];
}

#pragma mark -
#pragma mark Redirects
-(void)redirectRequest:(NSString *)urlPath toTarget:(id)target action:(SEL)action{
  if (!!target) {
    NSInvocation *redirect = [NSInvocation invocationWithMethodSignature:[[target class] instanceMethodSignatureForSelector:action]];
    redirect.target = target;
    redirect.selector = action;
    
    [_redirects setValue:redirect forKey:urlPath];
  } else {
    [_redirects setValue:nil forKey:urlPath];
  }
}

-(void)handleLaunch:(NSDictionary *)queryComponents{
  NSString *urlPath = [queryComponents valueForKey:@"url"];
  if (!!urlPath && [urlPath isKindOfClass:[NSString class]]) {
    PHURLLoaderView *view = [[PHURLLoaderView alloc] initWithTargetURLPath:urlPath];
    view.delegate = self;
    [view show:YES];
    [view release];
  }
}

-(void)handleDismiss:(NSDictionary *)queryComponents{
  NSString *pingPath = [queryComponents valueForKey:@"ping"];
  if (!!pingPath && [pingPath isKindOfClass:[NSString class]]) {
    PHURLLoader *loader = [[PHURLLoader alloc] init];
    loader.opensFinalURLOnDevice = NO;
    loader.targetURL = [NSURL URLWithString:pingPath];
    
    [loader open];
    [loader release];
  }
  
  [self dismiss:_willAnimate];
}

-(void)handleLoadContext:(NSDictionary *)queryComponents callback:(NSString*)callback{
  [self sendCallback:callback withResponse:self.content.context error:nil];
}

#pragma mark - callbacks
-(void)sendCallback:(NSString *)callback withResponse:(id)response error:(id)error{
  NSString *_callback = @"null", *_response = @"null", *_error = @"null";
  if (!!callback) _callback = callback;
  if (!!response) _response = [response JSONRepresentation];
  if (!!error) _error = [error JSONRepresentation];
  
  NSString *callbackCommand = [NSString stringWithFormat:@"PlayHaven.native.callback(\"%@\",%@,%@)", _callback, _response, _error];
  [_webView stringByEvaluatingJavaScriptFromString:callbackCommand];
}

#pragma mark -
#pragma mark PHURLLoaderDelegate
-(void)loaderFinished:(PHURLLoader *)loader{
  [self dismissFromButton];
}
@end

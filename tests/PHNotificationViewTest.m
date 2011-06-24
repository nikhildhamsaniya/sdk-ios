//
//  PHNotificationViewTest.m
//  playhaven-sdk-ios
//
//  Created by Jesus Fernandez on 3/30/11.
//  Copyright 2011 Playhaven. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <UIKit/UIKit.h>
#import "PHNotificationView.h"
#import "PHNotificationRenderer.h"
#import "PHNotificationBadgeRenderer.h"
@interface PHNotificationViewTest : SenTestCase
@end


@implementation PHNotificationViewTest

-(void)testInstance{
  PHNotificationView *notificationView = [[PHNotificationView alloc] initWithApp:@"" secret:@"" placement:@""];
  STAssertNotNil(notificationView, @"expected notification view instance, got nil");
  STAssertTrue([notificationView respondsToSelector:@selector(refresh)], @"refresh method not present");
  
  [notificationView release];
}

-(void)testRendererAssignment{
  NSString *type = @"non_existent_badge_type";
  NSDictionary *notificationData = [NSDictionary dictionaryWithObjectsAndKeys:
                                    type, @"type", 
                                    nil];
  
  PHNotificationRenderer *renderer = [PHNotificationView newRendererForData:notificationData];
  STAssertTrue([renderer isKindOfClass:[PHNotificationRenderer class]], @"expected PHNotificationRenderer instance, got something else!");
  
  [PHNotificationView setRendererClass:[PHNotificationBadgeRenderer class] forType:type];
  [renderer release], renderer = [PHNotificationView newRendererForData:notificationData];
  STAssertTrue([renderer isKindOfClass:[PHNotificationBadgeRenderer class]], @"expected PHNotificationBadgeRenderer instance, got something else!");
  
  [renderer release];
}

@end

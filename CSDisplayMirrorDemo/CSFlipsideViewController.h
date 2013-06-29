//
//  CSFlipsideViewController.h
//  CSDisplayMirrorDemo
//
//  Created by CoolStar on 6/29/13.
//  Copyright (c) 2013 CoolStar. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CSFlipsideViewController;

@protocol CSFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(CSFlipsideViewController *)controller;
@end

@interface CSFlipsideViewController : UIViewController

@property (assign, nonatomic) id <CSFlipsideViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;

@end

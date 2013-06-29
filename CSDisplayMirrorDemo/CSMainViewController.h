//
//  CSMainViewController.h
//  CSDisplayMirrorDemo
//
//  Created by CoolStar on 6/29/13.
//  Copyright (c) 2013 CoolStar. All rights reserved.
//

#import "CSFlipsideViewController.h"

@interface CSMainViewController : UIViewController <CSFlipsideViewControllerDelegate> {
    IBOutlet UIWebView *_webView;
}

@property (strong, nonatomic) UIPopoverController *flipsidePopoverController;

- (IBAction)showInfo:(id)sender;

@end

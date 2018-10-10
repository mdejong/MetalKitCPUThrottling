//
//  ViewController.m
//  MetalKitCPUThrottling
//
//  Created by Mo DeJong on 10/10/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import "ViewController.h"

@import MetalKit;

@interface ViewController ()

@property (nonatomic, retain) MTKView *mtkView;

@end

@implementation ViewController

- (void )viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  CGRect rect = self.view.frame;
  MTKView *mtkView = [[MTKView alloc] initWithFrame:rect];
  self.mtkView = mtkView;

  mtkView.backgroundColor = [UIColor redColor];
  
  [self.view addSubview:mtkView];
  
  mtkView.device = MTLCreateSystemDefaultDevice();
}

- (void) viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGRect rect = self.view.frame;
  self.mtkView.frame = rect;
  NSLog(@"viewDidLayoutSubviews %3d x %3d", (int)rect.size.width, (int)rect.size.height);
}

@end

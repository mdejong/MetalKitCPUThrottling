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

@property (nonatomic, retain) id<MTLLibrary> defaultLibrary;

@property (nonatomic, retain) id<MTLComputePipelineState> computePipeline;

// Current render size for Metal view

@property (nonatomic, assign) vector_uint2 viewportSize;

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
  
  id<MTLLibrary> defaultLibrary = [mtkView.device newDefaultLibrary];
  NSAssert(defaultLibrary, @"defaultLibrary");
  self.defaultLibrary = defaultLibrary;
  
  [self setupMetalKitView:mtkView];
}

- (void) viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGRect rect = self.view.frame;
  self.mtkView.frame = rect;
  NSLog(@"viewDidLayoutSubviews %3d x %3d", (int)rect.size.width, (int)rect.size.height);
}

// Create Metal compute pipeline

- (id<MTLComputePipelineState>) makePipeline:(NSString*)pipelineLabel
                          kernelFunctionName:(NSString*)kernelFunctionName
{
  // Load the vertex function from the library
  
  id <MTLFunction> kernelFunction = [self.defaultLibrary newFunctionWithName:kernelFunctionName];
  NSAssert(kernelFunction, @"kernel function \"%@\" could not be loaded", kernelFunctionName);
  
  NSError *error = NULL;
  
  id<MTLComputePipelineState> state = [self.mtkView.device newComputePipelineStateWithFunction:kernelFunction
                                                                                 error:&error];
  
  if (!state)
  {
    NSLog(@"Failed to created pipeline state, error %@", error);
  }
  
  return state;
}

// Initialize with the MetalKit view from which we'll obtain our metal device

- (void) setupMetalKitView:(nonnull MTKView *)mtkView
{
  const int isCaptureRenderedTextureEnabled = 0;
  
  if (isCaptureRenderedTextureEnabled) {
    mtkView.framebufferOnly = false;
  }
  
  mtkView.delegate = (id<MTKViewDelegate>) self;
  
  mtkView.depthStencilPixelFormat = MTLPixelFormatInvalid;
  
  mtkView.preferredFramesPerSecond = 30;
  
  mtkView.paused = FALSE;
  
  self.computePipeline = [self makePipeline:@"compute" kernelFunctionName:@"compute_kernel_emit_pixel"];
  
  return;
}

// Called when view changes orientation or is resized

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
  vector_uint2 viewportSize;
  viewportSize.x = size.width;
  viewportSize.y = size.height;
  self.viewportSize = viewportSize;
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
  NSLog(@"drawInMTKView");
  return;
}

@end


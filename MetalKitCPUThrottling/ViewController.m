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
  
  [self setupMetalKitView:mtkView];
}

- (void) viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGRect rect = self.view.frame;
  self.mtkView.frame = rect;
  NSLog(@"viewDidLayoutSubviews %3d x %3d", (int)rect.size.width, (int)rect.size.height);
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
  
  /*
  
  id<MTLLibrary> defaultLibrary = self.metalRenderContext.defaultLibrary;
  
  {
    // Render to texture pipeline
    
    // Load the vertex function from the library
    id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    
    // Load the fragment function from the library
    id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingPassThroughShader"];
    
    {
      // Set up a descriptor for creating a pipeline state object
      MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
      pipelineStateDescriptor.label = @"Render From Texture Pipeline";
      pipelineStateDescriptor.vertexFunction = vertexFunction;
      pipelineStateDescriptor.fragmentFunction = fragmentFunction;
      pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
      //pipelineStateDescriptor.stencilAttachmentPixelFormat =  mtkView.depthStencilPixelFormat; // MTLPixelFormatStencil8
      
      _renderFromTexturePipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                                error:&error];
      if (!_renderFromTexturePipelineState)
      {
        // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
        //  If the Metal API validation is enabled, we can find out more information about what
        //  went wrong.  (Metal API validation is enabled by default when a debug build is run
        //  from Xcode)
        NSLog(@"Failed to created pipeline state, error %@", error);
      }
    }
  }

  */
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


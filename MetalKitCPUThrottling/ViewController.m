//
//  ViewController.m
//  MetalKitCPUThrottling
//
//  Created by Mo DeJong on 10/10/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import "ViewController.h"

@import MetalKit;

#import "MetalRenderContext.h"

#import "AAPLShaderTypes.h"

const static int textureDim = 1024;

@interface ViewController ()

@property (nonatomic, retain) MTKView *mtkView;

@property (nonatomic, retain) MetalRenderContext *metalRenderContext;

// Render from texture into the Metal view pipeline

@property (nonatomic, retain) id<MTLRenderPipelineState> renderIntoViewPipelineState;

// Current render size for Metal view

@property (nonatomic, assign) vector_uint2 viewportSize;

@property (nonatomic, retain) id<MTLCommandQueue> commandQueue;

// Buffer that will be read/written to in draw command

@property (nonatomic, retain) NSMutableData *readWriteData;

// Texture that will be rendered into and then the output will be resized into the view

@property (nonatomic, retain) id<MTLTexture> renderTexture;

@end

@implementation ViewController

- (void )viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  self.readWriteData = [NSMutableData dataWithLength:textureDim*textureDim*sizeof(uint32_t)];
  
  // Costly CPU operation : swap Blue and Green channels
  {
    uint32_t *pixelPtr = (uint32_t *) self.readWriteData.mutableBytes;
    int numPixels = (int) self.readWriteData.length / sizeof(uint32_t);
    
    uint32_t renderPixel = 0xFF0000FF; // Blue
    
    for (int i = 0; i < numPixels; i++) {
      pixelPtr[i] = renderPixel;
    }
  }
  
  CGRect rect = self.view.frame;
  MTKView *mtkView = [[MTKView alloc] initWithFrame:rect];
  self.mtkView = mtkView;

  mtkView.backgroundColor = [UIColor redColor];
  
  [self.view addSubview:mtkView];
  
  [self setupMetalKitView:mtkView];
  
  // Explicitly invoke size will change method the first itme
  
  [self mtkView:mtkView drawableSizeWillChange:mtkView.drawableSize];
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

  if (self.metalRenderContext == nil) {
    self.metalRenderContext = [[MetalRenderContext alloc] init];
    
    id <MTLDevice> device = MTLCreateSystemDefaultDevice();
    
    mtkView.device = device;
    
    [self.metalRenderContext setupMetal:device];
  }
  
  if (isCaptureRenderedTextureEnabled) {
    mtkView.framebufferOnly = false;
  }
  
  mtkView.delegate = self; // MTKViewDelegate
  
  mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  mtkView.depthStencilPixelFormat = MTLPixelFormatInvalid;
  
  mtkView.preferredFramesPerSecond = 30;
  
  //mtkView.paused = FALSE;

  self.renderIntoViewPipelineState = [self.metalRenderContext makePipeline:MTLPixelFormatBGRA8Unorm pipelineLabel:@"renderIntoView" numAttachments:1 vertexFunctionName:@"vertexShader" fragmentFunctionName:@"samplingPassThroughShader"];
  NSAssert(self.renderIntoViewPipelineState, @"renderIntoViewPipelineState");
  
  self.commandQueue = self.metalRenderContext.commandQueue;
  
  uint32_t *inPixels = NULL;
  
  if (1)
  {
    NSMutableData *mData = [NSMutableData dataWithLength:textureDim*textureDim*sizeof(uint32_t)];
    inPixels = mData.mutableBytes;
    int numPixels = (int)mData.length / sizeof(uint32_t);
    
    for (int i = 0; i < numPixels; i++) {
      uint32_t pixel;

      // Blue
      uint32_t b0 = 0xFF;
      uint32_t b1 = 0x0;
      uint32_t b2 = 0x0;
      uint32_t b3 = 0xFF;
      
      pixel = (b3 << 24) | (b2 << 16) | (b1 << 8) | (b0);
      
      inPixels[i] = pixel;
    }
  }
  
  self.renderTexture = [self.metalRenderContext makeBGRATexture:CGSizeMake(textureDim,textureDim) pixels:inPixels usage:MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite];
  
  // Init with (-1,-1) until actual size method is invoked

  {
    vector_uint2 viewportSize;
    viewportSize.x = -1;
    viewportSize.y = -1;
    self.viewportSize = viewportSize;
  }
  
  return;
}

// Called when view changes orientation or is resized

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
  vector_uint2 viewportSize;
  viewportSize.x = size.width;
  viewportSize.y = size.height;
  self.viewportSize = viewportSize;
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
  //NSLog(@"drawInMTKView %p", view);
  
  if (self.viewportSize.x == -1) {
    NSLog(@"drawInMTKView : viewportSize not set");
    return;
  }
  
  CFTimeInterval draw_start_time = CACurrentMediaTime();
  
  // Costly CPU operation : swap Blue and Green channels
  {
    uint32_t *pixelPtr = (uint32_t *) self.readWriteData.mutableBytes;
    int numPixels = (int) self.readWriteData.length / sizeof(uint32_t);

    if ((0))
    {
      id<MTLTexture> texture = self.renderTexture;
      int width = (int) texture.width;
      int height = (int) texture.height;
      
      assert((width * height * sizeof(uint32_t)) == self.readWriteData.length);
      
      [texture getBytes:(void*)pixelPtr
            bytesPerRow:width*sizeof(uint32_t)
          bytesPerImage:width*height*sizeof(uint32_t)
             fromRegion:MTLRegionMake2D(0, 0, width, height)
            mipmapLevel:0
                  slice:0];
    }

    for (int count = 0; count < 3; count++) {
      for (int i = 0; i < numPixels; i++) {
        uint32_t pixel = pixelPtr[i];
        
        uint32_t b0 = pixel & 0xFF;
        uint32_t b1 = (pixel >> 8) & 0xFF;
        uint32_t b2 = (pixel >> 16) & 0xFF;
        uint32_t b3 = (pixel >> 24) & 0xFF;
        
        // swap
        uint32_t tmp = b0;
        b0 = b1;
        b1 = tmp;
        
        pixel = (b3 << 24) | (b2 << 16) | (b1 << 8) | (b0);
        pixelPtr[i] = pixel;
      }
    }

    // Copy into texture
    [self.metalRenderContext fillBGRATexture:self.renderTexture pixels:pixelPtr];
  }
  
  // Create a new command buffer
  
  id <MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
  commandBuffer.label = @"RenderCompute";

  // Clear to background color with a trival render operation
  
  MTKView *mtkView = self.mtkView;
  
  MTLRenderPassDescriptor *renderPassDescriptor = mtkView.currentRenderPassDescriptor;
  
  if (renderPassDescriptor != nil) {
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    renderEncoder.label = @"RenderIntoView";
    
    [renderEncoder pushDebugGroup:@"RenderIntoView"];
    
    [renderEncoder setRenderPipelineState:self.renderIntoViewPipelineState];
    
    MTLViewport mtlvp = {0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 };
    [renderEncoder setViewport:mtlvp];
    
    [renderEncoder setVertexBuffer:self.metalRenderContext.identityVerticesBuffer
                            offset:0
                           atIndex:AAPLVertexInputIndexVertices];
    
    [renderEncoder setFragmentTexture:self.renderTexture
                              atIndex:AAPLTextureIndexes];
    
    // Draw the 3 vertices of our triangle
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:self.metalRenderContext.identityNumVertices];
    
    [renderEncoder popDebugGroup];
    
    [renderEncoder endEncoding];
  }

  id<CAMetalDrawable> drawable = mtkView.currentDrawable;
  
  if (drawable) {
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
  }
  
  CFTimeInterval draw_stop_time = CACurrentMediaTime();
  
  printf("drawInMTKView time %.2f ms\n", (draw_stop_time-draw_start_time) * 1000);
  
  return;
}

@end


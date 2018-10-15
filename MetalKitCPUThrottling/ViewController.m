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
//const static int textureDim = 1024*2;

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

@property (nonatomic, retain) id<MTLTexture> renderTexture1;
@property (nonatomic, retain) id<MTLTexture> renderTexture2;
@property (nonatomic, retain) id<MTLTexture> renderTexture3;

@property (nonatomic, retain) NSMutableArray *availableTextures;
@property (nonatomic, retain) NSMutableArray *renderedTextures;

@property (nonatomic, retain) dispatch_semaphore_t decodeTextureSemaphore;

@end

@implementation ViewController

- (void )viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  self.readWriteData = [NSMutableData dataWithLength:textureDim*textureDim*sizeof(uint32_t)];
  
  [self pixelSetAllBlue];
  
  self.decodeTextureSemaphore = dispatch_semaphore_create(0);
  
  CGRect rect = self.view.frame;
  MTKView *mtkView = [[MTKView alloc] initWithFrame:rect];
  self.mtkView = mtkView;

  mtkView.backgroundColor = [UIColor redColor];
  
  [self.view addSubview:mtkView];
  
  [self setupMetalKitView:mtkView];
  
  // Explicitly invoke size will change method the first itme
  
  [self mtkView:mtkView drawableSizeWillChange:mtkView.drawableSize];
}

- (void) pixelSetAllBlue
{
  NSMutableData *readWriteData = self.readWriteData;
  
  uint32_t *pixelPtr = (uint32_t *) readWriteData.mutableBytes;
  int numPixels = (int) readWriteData.length / sizeof(uint32_t);
  
  uint32_t renderPixel = 0xFF0000FF; // Blue
  
  for (int i = 0; i < numPixels; i++) {
    pixelPtr[i] = renderPixel;
  }
}

- (void) doDecodeOp
{
//#define DECODE_PRINTF
  
  // Kick off decode
  
  __weak typeof(self) weakSelf = self;
  __block typeof(self.readWriteData) readWriteData = self.readWriteData;
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0), ^{
    
    while (1) {
      // FIXME: check exit decoding loop condition on weakSelf here
      
#if defined(DECODE_PRINTF)
      CFTimeInterval decode_start_time = CACurrentMediaTime();
      
      printf("decode into readWriteData\n");
#endif // DECODE_PRINTF
      
      // Execute CPU intensive operation, this logic grabs the next available
      // texture once it becomes available.
      
      uint32_t *pixelPtr = (uint32_t *) readWriteData.mutableBytes;
      int numPixels = (int) readWriteData.length / sizeof(uint32_t);
      
      /*
       // This impl writes 32 bit values to memory instead of read/write swap
      
      uint32_t renderPixelBlue = 0xFF0000FF; // Blue
      uint32_t renderPixelGreen = 0xFF00FF00; // Green

      uint32_t firstPixel = pixelPtr[0];
      
      uint32_t renderPixel;
      
      if (firstPixel == renderPixelBlue) {
        renderPixel = renderPixelGreen;
      } else {
        renderPixel = renderPixelBlue;
      }
      
      for (int i = 0; i < numPixels; i++) {
        pixelPtr[i] = renderPixel;
      }
       
      */
      
      // Read existing buffer values and swap Blue to Green
      
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
      
#if defined(DECODE_PRINTF)
      CFTimeInterval decode_stop_time = CACurrentMediaTime();
      
      printf("decode render %.2f ms, waiting for output buffer\n", (decode_stop_time-decode_start_time) * 1000);
#endif // DECODE_PRINTF
      
      // Wait for signal that indicates that an output buffer is available
      
      dispatch_semaphore_wait(weakSelf.decodeTextureSemaphore, DISPATCH_TIME_FOREVER);
      
      // Copy into texture on main thread
      
      dispatch_sync(dispatch_get_main_queue(), ^{
        // Modify availableTextures in main thread only
        
        __block id<MTLTexture> renderIntoTexture;
        
        renderIntoTexture = weakSelf.availableTextures[0];
        [weakSelf.availableTextures removeObjectAtIndex:0];
        
#if defined(DECODE_PRINTF)
        printf("copy into texture %p on main thread\n", renderIntoTexture);
#endif // DECODE_PRINTF
        
        // Copy into texture 1 or texture 2
        [weakSelf.metalRenderContext fillBGRATexture:renderIntoTexture pixels:pixelPtr];
        
        [weakSelf.renderedTextures addObject:renderIntoTexture];
      });
    }
    
  });
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
  
  self.availableTextures = [NSMutableArray array];
  self.renderedTextures = [NSMutableArray array];
  
  self.renderTexture1 = [self.metalRenderContext makeBGRATexture:CGSizeMake(textureDim,textureDim) pixels:NULL usage:MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite];
  self.renderTexture2 = [self.metalRenderContext makeBGRATexture:CGSizeMake(textureDim,textureDim) pixels:NULL usage:MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite];
  self.renderTexture3 = [self.metalRenderContext makeBGRATexture:CGSizeMake(textureDim,textureDim) pixels:NULL usage:MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite];
  
  [self.availableTextures addObject:self.renderTexture1];
  dispatch_semaphore_signal(self.decodeTextureSemaphore);
  
  [self.availableTextures addObject:self.renderTexture2];
  dispatch_semaphore_signal(self.decodeTextureSemaphore);

  [self.availableTextures addObject:self.renderTexture3];
  dispatch_semaphore_signal(self.decodeTextureSemaphore);
  
  // Init with (-1,-1) until actual size method is invoked

  {
    vector_uint2 viewportSize;
    viewportSize.x = -1;
    viewportSize.y = -1;
    self.viewportSize = viewportSize;
  }
  
  [self doDecodeOp];
  
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
//#define DRAW_INVIEW_TIMING
  
  //NSLog(@"drawInMTKView %p", view);
  
  if (self.viewportSize.x == -1) {
    NSLog(@"drawInMTKView : viewportSize not set");
    return;
  }
  
#if defined(DRAW_INVIEW_TIMING)
  CFTimeInterval draw_start_time = CACurrentMediaTime();
#endif // DRAW_INVIEW_TIMING

  // Get next rendered texture

  if (self.renderedTextures.count == 0) {
    NSLog(@"drawInMTKView : no renderedTextures, skip draw");
    return;
  }
  
  id<MTLTexture> renderTexture = self.renderedTextures[0];
  [self.renderedTextures removeObjectAtIndex:0];
  
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
    
    [renderEncoder setFragmentTexture:renderTexture
                              atIndex:AAPLTextureIndexes];
    
    // Draw the 3 vertices of our triangle
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:self.metalRenderContext.identityNumVertices];
    
    [renderEncoder popDebugGroup];
    
    [renderEncoder endEncoding];
  }

  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer){
    [self.availableTextures addObject:renderTexture];
    dispatch_semaphore_signal(self.decodeTextureSemaphore);
  }];
  
  id<CAMetalDrawable> drawable = mtkView.currentDrawable;
  
  if (drawable) {
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
  }
  
#if defined(DRAW_INVIEW_TIMING)
  CFTimeInterval draw_stop_time = CACurrentMediaTime();
  printf("drawInMTKView time %.2f ms\n", (draw_stop_time-draw_start_time) * 1000);
#endif // DRAW_INVIEW_TIMING
  
  return;
}

@end

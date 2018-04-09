//
//  KxMovieGLView.m
//  kxmovie
//
//  Created by Kolyvan on 22.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import "KxMovieGLView.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "KxMovieDecoder.h"

//////////////////////////////////////////////////////////

#pragma mark - shaders

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 uniform mat4 modelViewProjectionMatrix;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position =  position;
     v_texcoord = texcoord.xy;
 }
);

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D s_texture;
 
 void main()
 {
     gl_FragColor = texture2D(s_texture, v_texcoord);
 }
);

NSString *const yuvFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_u;
 uniform sampler2D s_texture_v;
 
 void main()
 {
     highp float y = texture2D(s_texture_y, v_texcoord).r;
     highp float u = texture2D(s_texture_u, v_texcoord).r - 0.5;
     highp float v = texture2D(s_texture_v, v_texcoord).r - 0.5;
     
     highp float r = y +             1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r,g,b,1.0);     
 }
);

static BOOL validateProgram(GLuint prog)
{
	GLint status;
	
    glValidateProgram(prog);
    
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {

        return NO;
    }
	
	return YES;
}

static GLuint compileShader(GLenum type, NSString *shaderString)
{
	GLint status;
	const GLchar *sources = (GLchar *)shaderString.UTF8String;
	
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {

        return 0;
    }
    
    glShaderSource(shader, 1, &sources, NULL);
    glCompileShader(shader);
	
#ifdef DEBUG
	GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);

        free(log);
    }
#endif
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
		
        return 0;
    }
    
	return shader;
}

//static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
//{
//    float r_l = right - left;
//    float t_b = top - bottom;
//    float f_n = far - near;
//    float tx = - (right + left) / (right - left);
//    float ty = - (top + bottom) / (top - bottom);
//    float tz = - (far + near) / (far - near);
//
//    mout[0] = 2.0f / r_l;
//    mout[1] = 0.0f;
//    mout[2] = 0.0f;
//    mout[3] = 0.0f;
//
//    mout[4] = 0.0f;
//    mout[5] = 2.0f / t_b;
//    mout[6] = 0.0f;
//    mout[7] = 0.0f;
//
//    mout[8] = 0.0f;
//    mout[9] = 0.0f;
//    mout[10] = -2.0f / f_n;
//    mout[11] = 0.0f;
//
//    mout[12] = tx;
//    mout[13] = ty;
//    mout[14] = tz;
//    mout[15] = 1.0f;
//}

//////////////////////////////////////////////////////////

#pragma mark - frame renderers

@protocol KxMovieGLRenderer

- (BOOL) isValid;
- (NSString *) fragmentShader;
- (void) resolveUniforms: (GLuint) program;
- (void) updateFrame: (KxVideoFrame *) frame;
- (BOOL) prepareRender;

@end

@interface KxMovieGLRenderer_RGB : NSObject<KxMovieGLRenderer> {
    GLint _uniformSampler;
    GLuint _texture;
}

@end

@implementation KxMovieGLRenderer_RGB

- (BOOL) isValid {
    return (_texture != 0);
}

- (NSString *) fragmentShader {
    return rgbFragmentShaderString;
}

- (void) resolveUniforms: (GLuint) program {
    _uniformSampler = glGetUniformLocation(program, "s_texture");
}

- (void) updateFrame: (KxVideoFrame *) frame {
    KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB *)frame;
    
    if (rgbFrame.hasAlpha) {
        assert(rgbFrame.rgb.length == rgbFrame.width * rgbFrame.height * 4);
    } else {
        assert(rgbFrame.rgb.length == rgbFrame.width * rgbFrame.height * 3);
    }
    
//    // Create a CVOpenGLESTexture from a CVPixelBufferRef
//    CVOpenGLESTextureRef texture = NULL;
//    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage( kCFAllocatorDefault,
//                                                                textureCache,
//                                                                pixelBuffer,
//                                                                NULL,
//                                                                GL_TEXTURE_2D,
//                                                                GL_RGBA,
//                                                                (GLsizei)frameWidth,
//                                                                (GLsizei)frameHeight,
//                                                                GL_BGRA,
//                                                                GL_UNSIGNED_BYTE,
//                                                                0,
//                                                                &texture );
//    
//    
//    if ( ! texture || err ) {
//        NSLog( @"CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err );
//        return;
//    }
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    GLint internalformat = rgbFrame.hasAlpha ? GL_RGBA : GL_RGB;
    GLint format = rgbFrame.hasAlpha ? GL_BGRA: GL_RGB;
    if (0 == _texture) {
        glGenTextures(1, &_texture);
    }
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 internalformat,
                 (int)frame.width,
                 (int)frame.height,
                 0,
                 format,
                 GL_UNSIGNED_BYTE,
                 rgbFrame.rgb.bytes);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (BOOL) prepareRender {
    if (_texture == 0)
        return NO;
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(_uniformSampler, 0);
    
    return YES;
}

- (void) dealloc {
    if (_texture) {
        glDeleteTextures(1, &_texture);
        _texture = 0;
    }
}

@end

@interface KxMovieGLRenderer_YUV : NSObject<KxMovieGLRenderer> {
    GLint _uniformSamplers[3];
    GLuint _textures[3];
}

@end

@implementation KxMovieGLRenderer_YUV

- (BOOL) isValid {
    return (_textures[0] != 0);
}

- (NSString *) fragmentShader {
    return yuvFragmentShaderString;
}

- (void) resolveUniforms: (GLuint) program {
    _uniformSamplers[0] = glGetUniformLocation(program, "s_texture_y");
    _uniformSamplers[1] = glGetUniformLocation(program, "s_texture_u");
    _uniformSamplers[2] = glGetUniformLocation(program, "s_texture_v");
}

- (void) updateFrame: (KxVideoFrame *) frame {
    KxVideoFrameYUV *yuvFrame = (KxVideoFrameYUV *)frame;
    
    assert(yuvFrame.luma.length == yuvFrame.width * yuvFrame.height);
    assert(yuvFrame.chromaB.length == (yuvFrame.width * yuvFrame.height) / 4);
    assert(yuvFrame.chromaR.length == (yuvFrame.width * yuvFrame.height) / 4);
    
    const NSUInteger frameWidth = frame.width;
    const NSUInteger frameHeight = frame.height;    
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (0 == _textures[0])
        glGenTextures(3, _textures);
    
    const UInt8 *pixels[3] = { yuvFrame.luma.bytes, yuvFrame.chromaB.bytes, yuvFrame.chromaR.bytes };
    const NSUInteger widths[3]  = { frameWidth, frameWidth / 2, frameWidth / 2 };
    const NSUInteger heights[3] = { frameHeight, frameHeight / 2, frameHeight / 2 };
    
    for (int i = 0; i < 3; ++i) {
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     (GLsizei)widths[i],
                     (GLsizei)heights[i],
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     pixels[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }     
}

- (BOOL) prepareRender {
    if (_textures[0] == 0)
        return NO;
    
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        glUniform1i(_uniformSamplers[i], i);
    }
    
    return YES;
}

- (void) dealloc {
    if (_textures[0])
        glDeleteTextures(3, _textures);
}

@end

//////////////////////////////////////////////////////////

#pragma mark - gl view

enum {
	ATTRIBUTE_VERTEX,
   	ATTRIBUTE_TEXCOORD,
};

@implementation KxMovieGLView {
    EAGLContext     *_context;
    GLuint          _framebuffer;
    GLuint          _renderbuffer;
    GLint           _backingWidth;
    GLint           _backingHeight;
    GLuint          _program;
    GLint           _uniformMatrix;
    GLfloat         _vertices[8];
    
    CGSize boundsSizeAtFrameBufferEpoch;
    id<KxMovieGLRenderer> _renderer;
    
    CIContext *_ciContext;
    CVOpenGLESTextureCacheRef _textureCache;
    
    KxVideoFrameFormat format;
    NSUInteger srcWidth;
    NSUInteger srcHeight;
}

+ (Class) layerClass {
	return [CAEAGLLayer class];
}

static NSDictionary *SCContextCreateCIContextOptions() {
    return @{kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null]};
}

- (id) initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _ciContext = [CIContext contextWithEAGLContext:_context options:SCContextCreateCIContextOptions()];
        self.contentScaleFactor = [UIScreen mainScreen].scale;
        if (!_context || ![EAGLContext setCurrentContext:_context]) {
            self = nil;
            return nil;
        }
        srcWidth = 0;
        srcHeight = 0;
        format = KxVideoFrameFormatRGB;
        [self createDisplayFramebuffer];
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE) {
            self = nil;
            return nil;
        }
        
        GLenum glError = glGetError();
        if (GL_NO_ERROR != glError) {
            self = nil;
            return nil;
        }
        
        _vertices[0] = -1.0f;  // x0
        _vertices[1] = -1.0f;  // y0
        _vertices[2] =  1.0f;  // ..
        _vertices[3] = -1.0f;
        _vertices[4] = -1.0f;
        _vertices[5] =  1.0f;
        _vertices[6] =  1.0f;  // x3
        _vertices[7] =  1.0f;  // y3
    }
    
    return self;
}

- (void)createDisplayFramebuffer {
    [EAGLContext setCurrentContext:_context];
    
    glGenFramebuffers(1, &_framebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    if ((_backingWidth == 0) || (_backingHeight == 0)) {
        [self destroyDisplayFramebuffer];
        return;
    }
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failure with display framebuffer generation for display of size: %d %d", _backingWidth, _backingHeight);
    }
    boundsSizeAtFrameBufferEpoch = self.bounds.size;
}

- (void)destroyDisplayFramebuffer; {
    [EAGLContext setCurrentContext:_context];
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
}

- (void)dealloc {
    _renderer = nil;
    
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
	if ([EAGLContext currentContext] == _context) {
		[EAGLContext setCurrentContext:nil];
	}
    
	_context = nil;
}

- (void)layoutSubviews {
    // The frame buffer needs to be trashed and re-created when the view size changes.
    if (!CGSizeEqualToSize(self.bounds.size, boundsSizeAtFrameBufferEpoch) &&
        !CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        [self destroyDisplayFramebuffer];
        [self createDisplayFramebuffer];
    }
}

- (void)setContentMode:(UIViewContentMode)contentMode {
    [super setContentMode:contentMode];
    // [self updateVertices];
    if (_renderer.isValid)
        [self render:nil];
}

- (void)flush {
    [self render:nil];
    _renderer = nil;
    srcWidth = 0;
    srcHeight = 0;
    if (_textureCache) {
        CFRelease( _textureCache );
        _textureCache = 0;
    }
}

- (UIImage *)curImage {
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    NSInteger dataLength = _backingWidth * _backingHeight * 4;
    GLubyte *data = (GLubyte *)malloc(dataLength * sizeof(GLubyte));
    NSAssert(data != nil, @"");
    
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(0, 0, _backingWidth, _backingHeight, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    // Create a CGImage with the pixel data
    // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
    // otherwise, use kCGImageAlphaPremultipliedLast
    CGDataProviderRef providerRef = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(_backingWidth, _backingHeight, 8, 32,
                                        _backingWidth * 4,
                                        colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                        providerRef, NULL, true, kCGRenderingIntentDefault);
    
    NSInteger widthInPoints, heightInPoints;
//    CGFloat scale = [[UIScreen mainScreen] scale];
    widthInPoints = srcWidth;
    heightInPoints = srcHeight;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(widthInPoints, heightInPoints), NO, 1);
    
    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
    // UIKit coordinate system is upside down to GL/Quartz coordinate system
    // Flip the CGImage by rendering it to the flipped bitmap context
    // The size of the destination area is measured in POINTS
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    
    // CPU占比高，不能不停的调用
    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, widthInPoints, heightInPoints), imageRef);
    
    // Retrieve the UIImage from the current context
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    free(data);
    CGImageRelease(imageRef);
    CGDataProviderRelease(providerRef);
    CGColorSpaceRelease(colorspace);
    
    return image;
}

- (BOOL)loadShaders {
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    
	_program = glCreateProgram();
	
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShaderString);
    if (!vertShader) {
        goto exit;
    }
    
	fragShader = compileShader(GL_FRAGMENT_SHADER, _renderer.fragmentShader);
    if (!fragShader) {
        goto exit;
    }
    
	glAttachShader(_program, vertShader);
	glAttachShader(_program, fragShader);
	glBindAttribLocation(_program, ATTRIBUTE_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIBUTE_TEXCOORD, "texcoord");
	
	glLinkProgram(_program);
    
    GLint status;
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
		// LoggerVideo(0, @"Failed to link program %d", _program);
        goto exit;
    }
    
    result = validateProgram(_program);
    
    _uniformMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    [_renderer resolveUniforms:_program];
	
exit:
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        // LoggerVideo(1, @"OK setup GL programm");
    } else {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    return result;
}

- (void)updateVertices {
    const BOOL fit      = YES;//(self.contentMode == UIViewContentModeScaleAspectFit);
    const float width   = 1920;
    const float height  = 1080;
    const float dH      = (float)_backingHeight / height;
    const float dW      = (float)_backingWidth	  / width;
    const float dd      = fit ? MIN(dH, dW) : MAX(dH, dW);
    const float h       = (height * dd / (float)_backingHeight);
    const float w       = (width  * dd / (float)_backingWidth );
    
    _vertices[0] = - w;
    _vertices[1] = - h;
    _vertices[2] =   w;
    _vertices[3] = - h;
    _vertices[4] = - w;
    _vertices[5] =   h;
    _vertices[6] =   w;
    _vertices[7] =   h;
}

- (void)render:(KxVideoFrame *)frame {
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
	
    [EAGLContext setCurrentContext:_context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    if (frame != nil) {
        if (format != frame.format) {
            _renderer = nil;
        } else if (srcWidth != frame.width || srcHeight != frame.height) {
            srcWidth = frame.width;
            srcHeight = frame.height;
            _renderer = nil;
        }
        
        if (_renderer == nil) {
            if (_program) {
                glDeleteProgram(_program);
                _program = 0;
            }
            
            if (frame.format == KxVideoFrameFormatRGB) {
                _renderer = [[KxMovieGLRenderer_RGB alloc] init];
            } else {
                _renderer = [[KxMovieGLRenderer_YUV alloc] init];
            }
            
            if (![self loadShaders]) {
                NSLog(@"load shaders failed");
            }
        }
        
        glUseProgram(_program);
        [_renderer updateFrame:frame];
        
        if ([_renderer prepareRender]) {
            glVertexAttribPointer(ATTRIBUTE_VERTEX, 2, GL_FLOAT, 0, 0, _vertices);
            glEnableVertexAttribArray(ATTRIBUTE_VERTEX);
            glVertexAttribPointer(ATTRIBUTE_TEXCOORD, 2, GL_FLOAT, 0, 0, texCoords);
            glEnableVertexAttribArray(ATTRIBUTE_TEXCOORD);
#if 0
            if (!validateProgram(_program)) {
                LoggerVideo(0, @"Failed to validate program");
                return;
            }
#endif
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        }
    } else {
        NSLog(@"flush");
    }
    
//    if (_textureCache == nil) {
//        //  Create a new CVOpenGLESTexture cache
//        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
//        if (err) {
//            NSLog( @"Error at CVOpenGLESTextureCacheCreate %d", err );
//        }
//    }

//    KxVideoFrameRGB *rgbFra = (KxVideoFrameRGB *)frame;
//    CGColorSpaceRef colorSpace;
//    colorSpace = CGColorSpaceCreateDeviceRGB();
//    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)rgbFra.rgb);
//    CGImageRef imageRef = CGImageCreate(rgbFra.width,          //width
//                                        rgbFra.height,         //height
//                                        8,              //bits per component
//                                        32,             //bits per pixel
//                                        rgbFra.width * 4,      //bytesPerRow
//                                        colorSpace,     //colorspace
//                                        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little,// bitmap info
//                                        provider,               //CGDataProviderRef
//                                        NULL,                   //decode
//                                        false,                  //should interpolate
//                                        kCGRenderingIntentDefault   //intent
//                                        );
//    
//    CIImage *cimage = [CIImage imageWithCGImage:imageRef];
//    [_ciContext drawImage:cimage inRect:CGRectMake(0, 0, _backingWidth, _backingHeight) fromRect:cimage.extent];
//    CGColorSpaceRelease(colorSpace);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        printf("GL_ERROR=======>%d\n", err);
    }
}

@end

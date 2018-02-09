//
//  AudioUnitPlayback.m
//  iMyCamera
//
//  Created by cs on 15/10/16.
//  Copyright © 2015年 MacBook. All rights reserved.
//

#import "AudioManager.h"
#import <Accelerate/Accelerate.h>
#include <vector>

static void sessionInterruptionListener(void *inClientData, UInt32 inInterruption) {
    
}

@interface AudioManager() {
    AudioUnit remoteIOUnit;
    SInt16 * _outData;
    BOOL _activated;
    BOOL _initialized;
}

@property (nonatomic, readwrite)BOOL playing;

- (void)fillBuf:(AudioBufferList *)ioData num:(UInt32)inNumberFrames;

@end

static BOOL checkError(OSStatus error, const char *operation) {
    if (error == noErr)
        return NO;
    
    char str[20] = {0};
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else {
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    }
    
    NSLog(@"Error: %s (%s)\n", operation, str);
    
    return YES;
}

@implementation AudioManager

+ (AudioManager *) sharedInstance {
    static AudioManager *audioManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        audioManager = [[AudioManager alloc] init];
    });
    
    return audioManager;
}

- (id)init {
    if (self = [super init]) {
        _outData = (SInt16 *)calloc(4096 * 2, sizeof(SInt16));
    }
    
    return self;
}

- (BOOL) activateAudioSession {
    if (!_initialized) {
        AudioSessionInitialize(NULL,
                               kCFRunLoopDefaultMode,
                               sessionInterruptionListener,
                               (__bridge void *)(self));
        
        _initialized = YES;
    }
    
    if (!_activated) {
        UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
        if (checkError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                               sizeof(sessionCategory),
                                               &sessionCategory),
                       "Couldn't set audio category"))
            return NO;
        
        if (checkError(AudioSessionSetActive(YES),
                       "Couldn't activate the audio session"))
            return NO;
        
        _activated = YES;
    }
    
    return _initialized;
}

- (void) deactivateAudioSession {
    [self stop];
    
    checkError(AudioSessionSetActive(NO),
               "Couldn't deactivate the audio session");
    _activated = NO;
}

- (void)stop {
    [self pause];
    
    if (remoteIOUnit != nil) {
        checkError(AudioUnitUninitialize(remoteIOUnit),
                   "Couldn't uninitialize the audio unit");
        
        checkError(AudioComponentInstanceDispose(remoteIOUnit),
                   "Couldn't dispose the output audio unit");
    }

    remoteIOUnit = nil;
}

- (BOOL)play {
    if (!_playing) {
        if ([self activateAudioSession] && [self setupAudio]) {
            _playing = !checkError(AudioOutputUnitStart(remoteIOUnit),
                                   "Couldn't start the output unit");
        }
    }
    
    return _playing;
}

- (void)pause {
    if (_playing) {
        checkError(AudioOutputUnitStop(remoteIOUnit),
                              "Couldn't stop the output unit");
    }
    
    _playing = NO;
}

- (void)dealloc {
    delete []_outData;
}

static OSStatus outputRenderCallback(void                        *inRefCon,
                                     AudioUnitRenderActionFlags  *ioActionFlags,
                                     const AudioTimeStamp        *inTimeStamp,
                                     UInt32                      inBusNumber,
                                     UInt32                      inNumberFrames,
                                     AudioBufferList             *ioData){
    AudioManager *output = (__bridge AudioManager*)inRefCon;
    
    [output fillBuf:ioData num:inNumberFrames];
    return noErr;
}

-(BOOL)setupAudio {
    if (remoteIOUnit != nil) {
        return YES;
    }
    
    AudioComponentDescription inputcd = {0};
    inputcd.componentType = kAudioUnitType_Output;
    inputcd.componentSubType = kAudioUnitSubType_RemoteIO;
    inputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AudioComponent component = AudioComponentFindNext(NULL, &inputcd);
    if (checkError(AudioComponentInstanceNew(component, &remoteIOUnit),
                 "Couldn't create the output audio unit")) {
        return NO;
    }
    
    AudioStreamBasicDescription streamFormat;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty(remoteIOUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &streamFormat,
                         &size);
    
    streamFormat.mFormatID = kAudioFormatLinearPCM;
    streamFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    streamFormat.mSampleRate = self.sampleRate;
    streamFormat.mChannelsPerFrame = self.channel;
    streamFormat.mBitsPerChannel = 16;
    streamFormat.mFramesPerPacket = 1;
    streamFormat.mBytesPerFrame = self.channel * 2;
    streamFormat.mBytesPerPacket = self.channel * 2;
    
    if (checkError(AudioUnitSetProperty(remoteIOUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      0,
                                      &streamFormat,
                                      sizeof(streamFormat)),
                 "kAudioUnitProperty_StreamFormat of bus 0 failed")) {
        return NO;
    }
    
    AURenderCallbackStruct input;
    input.inputProc = outputRenderCallback;
    input.inputProcRefCon = (__bridge void *)self;
    if (checkError(AudioUnitSetProperty(remoteIOUnit,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Input,
                                      0,//input mic
                                      &input,
                                      sizeof(input)),
                 "kAudioUnitProperty_SetRenderCallback failed")) {
        return NO;
    }
    
    if (checkError(AudioUnitInitialize(remoteIOUnit),
               "Couldn't initialize the audio unit")) {
        return NO;
    }
    
    _activated = YES;
    
    return YES;
}

- (void)fillBuf:(AudioBufferList *)ioData num:(UInt32)inNumberFrames {
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    if (_playing) {
        if (_outputBlock != nil) {
            _outputBlock(_outData, inNumberFrames, self.channel);
            
            for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                SInt16 *frameBuffer = (SInt16 *)ioData->mBuffers[iBuffer].mData;
                memcpy(frameBuffer, _outData, inNumberFrames * thisNumChannels * sizeof(SInt16));
            }
        }
    }
}

@end

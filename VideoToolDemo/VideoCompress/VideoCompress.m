//
//  VideoCompress.m
//  VideoDemo
//
//  Created by karos li on 2020/12/23.
//

#import "VideoCompress.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

/**
 原视频和压缩视频已经上传到网盘
 链接:https://pan.baidu.com/s/19yO94vp89fGpX5eNYSDFlg  密码:bde5
 
 手机录制的视频，时长1分钟，1920*1080 文件大小167MB,bitrate: 22220 kb/s
 上传后的比例是一样的。
 keep:
 压缩时长:8s，上传后的视频 576*1024 17MB, bitrate:2249 kb/s，数据密度：0.140
 微博：480P
 压缩时长:8s，上传后的视频  480*852 9.5MB, bitrate:1156 kb/s，数据密度：0.090
 小红书：720P
 压缩时长:8s，上传后的视频 720*1280 10.1MB ,bitrate:1262 kb/s，数据密度：0.046
 微信：
 压缩时长:6s，上传后的视频 544*960 8.8MB ,bitrate:1118 kb/s，数据密度：0.077
 抖音+西瓜：720P
 压缩时长:10s，上传后的视频 720*1280 18.1MB ,bitrate:2151 kb/s，数据密度：0.080
 微视：720P
 压缩时长:10s， 上传后的视频 720*1280 19.5MB ,bitrate:2550 kb/s，数据密度：0.092
 
 动态码率计算
 可以看到大厂的数据密度范围在：0.077~0.092，那我们可以根据抖音+西瓜的视频数据密度（0.080）就可以反推出一个合适的码率出来。
 根据公式：数据密度 = [码率/(像素*帧率)]，那么 码率 = [像素*帧率*数据密度]。
 例如：
 假设目标分辨率是 720P（1280x720），目标帧率是 30，那么 码率 = 1280 * 720 * 30 * 0.08 = 2160kb/s，大小 = 17.4MB
 

 */
@interface VideoCompress ()

@end

@implementation VideoCompress

+ (dispatch_queue_t)video_compression_queue {
    static dispatch_queue_t _video_compression_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _video_compression_queue = dispatch_queue_create("video_compression_queue", DISPATCH_QUEUE_SERIAL);
    });
    
    return _video_compression_queue;
}

+ (dispatch_queue_t)audio_compression_queue {
    static dispatch_queue_t _audio_compression_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _audio_compression_queue = dispatch_queue_create("audio_compression_queue", DISPATCH_QUEUE_SERIAL);
    });
    
    return _audio_compression_queue;
}

- (instancetype)init {
    self = [super init];
    return self;
}

+ (void)deleteOutputUrlIfNeed:(NSURL *)outputUrl {
    NSString *existUrl = [outputUrl.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    if ([[NSFileManager defaultManager] fileExistsAtPath:existUrl]) {
        [[NSFileManager defaultManager] removeItemAtPath:existUrl error:nil];
    }
}

/// 方法一
///
///  压缩
/// @param videoUrl 源视频
/// @param outputUrl 输出视频
- (void)compressVideo1:(NSURL *)videoUrl withOutputUrl:(NSURL *)outputUrl {
    NSLog(@"The size of original video at %@ is %0.2fM", videoUrl.path, [self fileSize:videoUrl]);
    CFTimeInterval start = CFAbsoluteTimeGetCurrent();
    
    AVAsset *asset = [AVAsset assetWithURL:videoUrl];
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset960x540];
    session.outputURL = outputUrl;
    session.outputFileType = AVFileTypeMPEG4;
    session.shouldOptimizeForNetworkUse = YES;
    [session exportAsynchronouslyWithCompletionHandler:^{
        switch (session.status) {
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"The size of output video at %@ is %0.2fM", outputUrl.path, [self fileSize:outputUrl]);
                CFTimeInterval end = CFAbsoluteTimeGetCurrent();
                CFTimeInterval duration = (end - start) * 1000.0;
                NSLog(@"Total duration: %f ms", duration);
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"compress failed for reason: %@", session.error);
                break;
            default:
                break;
        }
    }];
}


///
/// https://zhuanlan.zhihu.com/p/47047821
/// @param videoUrl 源视频
/// @param outputUrl 输出视频
- (void)compressVideo2:(NSURL *)videoUrl withOutputUrl:(NSURL *)outputUrl {
    NSLog(@"The size of original video at %@ is %0.2fM", videoUrl.path, [self fileSize:videoUrl]);
    CFTimeInterval start = CFAbsoluteTimeGetCurrent();
    
    AVAsset *asset = [AVAsset assetWithURL:videoUrl];
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:outputUrl fileType:AVFileTypeMPEG4 error:nil];
    writer.shouldOptimizeForNetworkUse = YES;
    
    // video part
    AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
//  这个方式不能移除视频的 rotation 信息
//    AVAssetReaderTrackOutput *videoOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:[self videoOutputSettings]];
    
    AVAssetReaderVideoCompositionOutput *videoCompositionOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:@[videoTrack] videoSettings:[self videoOutputSettings]];
    
    videoCompositionOutput.videoComposition = [self createVideoCompositionWithAsset:asset videoTrack:videoTrack];
    AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:[self videoCompressSettings:videoTrack]];
    
    if ([reader canAddOutput:videoCompositionOutput]) {
        [reader addOutput:videoCompositionOutput];
    }
    if ([writer canAddInput:videoInput]) {
        [writer addInput:videoInput];
    }
    
    // audio
    AVAssetTrack *audioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVAssetReaderTrackOutput *audioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:[self audioOutputSettings]];
    AVAssetWriterInput *audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:[self audioCompressSettings]];
    if ([reader canAddOutput:audioOutput]) {
        [reader addOutput:audioOutput];
    }
    if ([writer canAddInput:audioInput]) {
        [writer addInput:audioInput];
    }
    
    /// 开始读写
    [reader startReading];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    /// 视频逐帧写入
    [videoInput requestMediaDataWhenReadyOnQueue:[VideoCompress video_compression_queue] usingBlock:^{
        while ([videoInput isReadyForMoreMediaData]) {
            CMSampleBufferRef sampleBuffer;
            if ([reader status] == AVAssetReaderStatusReading && (sampleBuffer = [videoCompositionOutput copyNextSampleBuffer])) {
                BOOL result = [videoInput appendSampleBuffer:sampleBuffer];
                
                // determine progress
                CMTime presTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                CGFloat presTimeSeconds = CMTimeGetSeconds(presTime);
                CGFloat duration = CMTimeGetSeconds(asset.duration);
                CGFloat progress = presTimeSeconds / duration;
                
//                NSLog(@"compress progress %.1f%%", progress * 100);

                CFRelease(sampleBuffer);
                if (!result) {
                    [reader cancelReading];
                    dispatch_group_leave(group);
                    break;
                }
            } else {
//                NSLog(@"compress progress %.1f%%", 100.0);
                [videoInput markAsFinished];
                dispatch_group_leave(group);
                break;
            }
        }
    }];
    
    dispatch_group_enter(group);
    /// 音频逐帧写入
    [audioInput requestMediaDataWhenReadyOnQueue:[VideoCompress audio_compression_queue] usingBlock:^{
        while ([audioInput isReadyForMoreMediaData]) {
            CMSampleBufferRef sampleBuffer;
            if ([reader status] == AVAssetReaderStatusReading && (sampleBuffer = [audioOutput copyNextSampleBuffer])) {
                BOOL result = [audioInput appendSampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
                if (!result) {
                    [reader cancelReading];
                    dispatch_group_leave(group);
                    break;
                }
            } else {
                [audioInput markAsFinished];
                dispatch_group_leave(group);
                break;
            }
        }
    }];
    
    /// 完成压缩
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([reader status] == AVAssetReaderStatusReading) {
            [reader cancelReading];
        }
        switch (writer.status) {
            case AVAssetWriterStatusWriting:
            {
                [writer finishWritingWithCompletionHandler:^{
                    NSLog(@"The size of output video at %@ is %0.2fM", outputUrl.path, [self fileSize:outputUrl]);
                    CFTimeInterval end = CFAbsoluteTimeGetCurrent();
                    CFTimeInterval duration = (end - start) * 1000.0;
                    NSLog(@"Total duration: %f ms", duration);
                }];
            }
                break;
                
            default:
                break;
        }
    });
}

#pragma mark - 创建多轨道读取
- (AVMutableVideoComposition *)createVideoCompositionWithAsset:(AVAsset *)asset videoTrack:(AVAssetTrack *)videoTrack {
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition new];
    NSDictionary *videoCompressSettings = [self videoCompressSettings:videoTrack];
    NSInteger videoWidth = [videoCompressSettings[AVVideoWidthKey] integerValue];
    NSInteger videoHeight = [videoCompressSettings[AVVideoHeightKey] integerValue];
    CGSize targetSize = CGSizeMake(videoWidth, videoHeight);
    CGSize naturalSize = videoTrack.naturalSize;
    CGAffineTransform transform = videoTrack.preferredTransform;
    
    // 判断视频是否是垂直的
    CGRect rect = CGRectMake(0, 0, naturalSize.width, naturalSize.height);
    CGRect transformedRect = CGRectApplyAffineTransform(rect, transform);
    transform.tx -= transformedRect.origin.x;
    transform.ty -= transformedRect.origin.y;
    CGFloat videoAngleInDegrees = atan2(transform.b, transform.a) * 180 / M_PI;
    if (videoAngleInDegrees == 90 || videoAngleInDegrees == -90) {
        NSInteger tempWidth = naturalSize.width;
        naturalSize.width = naturalSize.height;
        naturalSize.height = tempWidth;
    }

    CGFloat frameRate = 30;
    videoComposition.frameDuration = CMTimeMake(1, frameRate);
    videoComposition.renderSize = naturalSize;
    
    // 居中视频
    CGFloat radio = 0;
    CGFloat xRadio = targetSize.width / naturalSize.width;
    CGFloat yRadio = targetSize.height / naturalSize.height;
    radio = MIN(xRadio, yRadio);
    
    CGFloat postWidth = naturalSize.width * radio;
    CGFloat postHeight = naturalSize.height * radio;
    CGFloat transX = (targetSize.width - postWidth) * 0.5;
    CGFloat transY = (targetSize.height - postHeight) * 0.5;
    
    CGAffineTransform matrix = CGAffineTransformMakeTranslation(transX / xRadio, transY / yRadio);
    matrix = CGAffineTransformScale(matrix, (radio / xRadio), (radio / yRadio));
    transform = CGAffineTransformConcat(transform, matrix);
    
    // 创建合并指令
    AVMutableVideoCompositionInstruction *compositionInstruction = [AVMutableVideoCompositionInstruction new];
    compositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    
    // 创建图层合并指令
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    // 旋转视频和平移视频去适配 renderSize 的宽高
    [layerInstruction setTransform:transform atTime:kCMTimeZero];

    compositionInstruction.layerInstructions = @[layerInstruction];
    videoComposition.instructions = @[compositionInstruction];
    
    [self addWaterLayerWithAVMutableVideoComposition:videoComposition];
    
    return videoComposition;
}

///  添加水印 https://www.jianshu.com/p/dea9559e226a
- (void)addWaterLayerWithAVMutableVideoComposition:(AVMutableVideoComposition*)mutableVideoComposition {
    //-------------------layer
    CALayer *watermarkLayer = [CALayer layer];
    [watermarkLayer setContents:(id)[UIImage imageNamed:@"pikaqiu"].CGImage];
//    watermarkLayer.bounds = CGRectMake(0, 0, 70, 70);
//    watermarkLayer.position = CGPointMake(mutableVideoComposition.renderSize.width/2, mutableVideoComposition.renderSize.height/4);
    
    watermarkLayer.frame = CGRectMake(20, mutableVideoComposition.renderSize.height - 20 - 130, 130, 130);
    
    CABasicAnimation *rotationAnima = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnima.fromValue = @(0);
    rotationAnima.toValue = @(-M_PI * 2);
    rotationAnima.repeatCount = HUGE_VALF;
    rotationAnima.duration = 2.0f;  //5s之后消失
    [rotationAnima setRemovedOnCompletion:NO];
    [rotationAnima setFillMode:kCAFillModeForwards];
    rotationAnima.beginTime = AVCoreAnimationBeginTimeAtZero;
    [watermarkLayer addAnimation:rotationAnima forKey:@"Aniamtion"];
    
    CALayer *videoLayer = [CALayer layer];
    videoLayer.frame = CGRectMake(0, 0, mutableVideoComposition.renderSize.width, mutableVideoComposition.renderSize.height);
    
    CALayer *parentLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, mutableVideoComposition.renderSize.width, mutableVideoComposition.renderSize.height);
    
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:watermarkLayer];
    
    mutableVideoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
}

#pragma mark - 获取期望的视频方向
/// https://www.jianshu.com/p/5433143cccd8
- (CGAffineTransform)getVideoTransform:(AVAssetTrack *)videoTrack {
    CGSize naturalSize = videoTrack.naturalSize;
    NSInteger videoAngleInDegrees = [self getVideoAngle:videoTrack];
    
    CGAffineTransform mixedTransform = CGAffineTransformIdentity;
    if (videoAngleInDegrees > 0) {
        CGAffineTransform translateToCenter = CGAffineTransformIdentity;
        if (videoAngleInDegrees == 90) {
            // M_PI 弧度 = 180角度
            // 表示视频在屏幕（home在下面的视角）左上，视频顶边贴着屏幕的左边，视频右边贴着屏幕的顶边。所以需要先想x轴（画布的左下角是原点）平移一个视频自然高度的距离让视频离开屏幕，然后再以视频左上角为锚点做顺时针90度，重新让视频回到屏幕，并贴合屏幕。
            translateToCenter = CGAffineTransformMakeTranslation(naturalSize.height, 0.0);
            mixedTransform = CGAffineTransformRotate(translateToCenter, M_PI_2);
        } else if (videoAngleInDegrees == 180) {
            //顺时针旋转180°
            translateToCenter = CGAffineTransformMakeTranslation(naturalSize.width, naturalSize.height);
            mixedTransform = CGAffineTransformRotate(translateToCenter, M_PI);
        } else if (videoAngleInDegrees == 270) {
            //顺时针旋转270°
            translateToCenter = CGAffineTransformMakeTranslation(0.0, naturalSize.width);
            mixedTransform = CGAffineTransformRotate(translateToCenter, M_PI_2*3.0);
        }
    }
    
    return mixedTransform;
}

#pragma mark - 判断视频是否是垂直方向
- (BOOL)isVideoPortrait:(AVAssetTrack *)videoTrack {
    NSInteger videoAngleInDegrees = [self getVideoAngle:videoTrack];
    if (videoAngleInDegrees == 90 || videoAngleInDegrees == -90) {
        return YES;
    }
    
    return NO;
}

- (NSInteger)getVideoAngle:(AVAssetTrack *)videoTrack {
    CGSize naturalSize = videoTrack.naturalSize;
    
    // 方向判断，设置合适的输出宽高
    CGAffineTransform transform = videoTrack.preferredTransform;
    CGRect rect = CGRectMake(0, 0, naturalSize.width, naturalSize.height);
    CGRect transformedRect = CGRectApplyAffineTransform(rect, transform);
    // transformedRect should have origin at 0 if correct; otherwise add offset to correct it
    transform.tx -= transformedRect.origin.x;
    transform.ty -= transformedRect.origin.y;
    NSInteger videoAngleInDegrees = atan2(transform.b, transform.a) * 180 / M_PI;
    
    return videoAngleInDegrees;
}

#pragma mark - 指定音视频的压缩码率，profile，帧率等关键参数信息
- (NSDictionary *)videoOutputSettings {
    NSDictionary *videoOutputProperties = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        (id)kCVPixelBufferOpenGLESCompatibilityKey: @YES
    };
    
    return videoOutputProperties;
}

- (NSDictionary *)videoCompressSettings:(AVAssetTrack *)videoTrack {
    AVVideoCodecType codeType;
    if (@available(iOS 11.0, *)) {
        codeType = AVVideoCodecTypeH264;
    } else {
        codeType = AVVideoCodecH264;
    }
    
    BOOL isVideoPortrait = [self isVideoPortrait:videoTrack];
    CGSize naturalSize = videoTrack.naturalSize;
    CGFloat longSide = naturalSize.width > naturalSize.height ? naturalSize.width : naturalSize.height;
    CGFloat shortSide = naturalSize.width > naturalSize.height ? naturalSize.height : naturalSize.width;
    CGFloat radio = shortSide / longSide;
    //  
    if (isVideoPortrait) {
        if (longSide < 1280) {
            naturalSize = CGSizeMake(shortSide, longSide);
        } else {
            naturalSize = CGSizeMake(floor(1280 * radio), 1280);
        }
    } else {
        if (longSide < 1280) {
            naturalSize = CGSizeMake(longSide, shortSide);
        } else {
            naturalSize = CGSizeMake(1280, floor(1280 * radio));
        }
    }
    
    // 目标：720P（1280x720），数据密度 = [码率/(像素*帧率)]，抖音+西瓜的视频数据密度是 0.08，这里可以参考这个数据密度来动态计算码率
    // 720P 的视频，计算后的码率大概在 2160kb/s
    CGFloat bitRate = naturalSize.width * naturalSize.height * 30 * 0.08;
    NSDictionary *compressionProperties = @{
        AVVideoAverageBitRateKey: @(bitRate),
        AVVideoExpectedSourceFrameRateKey: @30,
        AVVideoMaxKeyFrameIntervalKey: @30,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    };
    
    NSDictionary *videoCompressionProperties = @{
        AVVideoCodecKey: codeType,
        AVVideoWidthKey: @(naturalSize.width),
        AVVideoHeightKey: @(naturalSize.height),
        AVVideoCompressionPropertiesKey: compressionProperties,
        AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
    };
    
    return videoCompressionProperties;
}

- (NSDictionary *)audioOutputSettings {
    NSDictionary *audioOutputProperties = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM)
    };
    
    return audioOutputProperties;
}

- (NSDictionary *)audioCompressSettings {
    AudioChannelLayout stereoChannelLayout = {
        .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
        .mChannelBitmap = 0,
        .mNumberChannelDescriptions = 0
    };
    
    NSData *channelLayoutAsData = [NSData dataWithBytes:&stereoChannelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];
    NSDictionary *audioCompressionProperties = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVEncoderBitRateKey: @(128000),
        AVSampleRateKey: @(44100),
        AVChannelLayoutKey: channelLayoutAsData,
        AVNumberOfChannelsKey: @2
    };
    
    return audioCompressionProperties;
}

#pragma file 相关方法
- (float)fileSize:(NSURL *)path {
    long long fileSize = [[NSFileManager defaultManager] attributesOfItemAtPath:[path.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""] error:nil].fileSize;
    return fileSize / 1024.0 / 1024.0;
}

@end

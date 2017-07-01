//
//  BWPlayViewController.m
//  LiveForMobile
//
//  Created by  Sierra on 2017/6/26.
//  Copyright © 2017年 BaiFuTak. All rights reserved.
//

#import "BWPlayViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import "TXRTMPSDK/TXLivePlayer.h"
#import "BWPlayDecorateView.h"
#import "PlayUGCDecorateView.h"
#import "BWGiftView.h"
#import "PrivateMessageView.h"
#import "BWPlayShareView.h"

#define RTMP_PLAY_URL @"rtmp://20994.mpull.live.lecloud.com/live/leshiTest?&tm=20170627094926&sign=f190180247eb94c8db6f8b49177e83d9"

@interface BWPlayViewController () <TXLivePlayListener, TXVideoRecordListener, BWPlayDecorateDelegate, PlayUGCDecorateViewDelegate> {
    BOOL _isLivePlay; // 是否为播放直播视频
    TX_Enum_PlayType _playType;
}

@property (nonatomic, copy) NSString *rtmpURL; // 拉流地址
@property (nonatomic, strong) TXLivePlayConfig *livePlayerConfig;
@property (nonatomic, strong) TXLivePlayer *livePlayer;

@property (nonatomic, strong) UIView *videoParentView; // 视频画面的父view
@property (nonatomic, strong) BWPlayDecorateView *decorateView;

@property (nonatomic, strong) PlayUGCDecorateView *recordUGCView; // 短视频录制界面

@end

@implementation BWPlayViewController

#pragma mark - Life Cycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 1. 初始化
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAudioSessionEvent:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    // 1.0 初始化参数
    _isLivePlay = YES;
    self.rtmpURL = RTMP_PLAY_URL;
    
    // 1.1 拉流配置对象
    self.livePlayerConfig = [[TXLivePlayConfig alloc] init];
    
    // 1.2 拉流对象
    self.livePlayer = [[TXLivePlayer alloc] init];
    self.livePlayer.enableHWAcceleration = YES;
    
    // 2. 添加控件
    // 2.0 背景图
    UIImage *backgroundImage = [UIImage imageNamed:@"avatar_default"];
    UIImage *clipImage = backgroundImage;
    if (backgroundImage) {
//        UIImage *gaussBlurImage = [self gaussBlurImage:backgroundImage withGaussNumber:0.3];
//        UIImage *scaleImage = [self scaleImage:gaussBlurImage scaleToSize:CGSizeMake(WIDTH * (backgroundImage.size.width / backgroundImage.size.height), HEIGHT)];
//        clipImage = [self clipImage:scaleImage inRect:CGRectMake(0, 0, WIDTH, HEIGHT)];
//        clipImage = scaleImage;
    }
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    backgroundImageView.contentMode = UIViewContentModeScaleAspectFit;
    backgroundImageView.image = clipImage;
    [backgroundImageView setContentScaleFactor:[[UIScreen mainScreen] scale]];
    backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    backgroundImageView.clipsToBounds = YES;
    [self.view addSubview:backgroundImageView];
    
    // 2.1 视频画面的父view
    self.videoParentView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.videoParentView];
    
    [self configVideoView];
    
    // 2.2 拉流模块逻辑view, 里面展示了消息列表，弹幕动画，观众列表，美颜，美白等UI
    self.decorateView = [[BWPlayDecorateView alloc] initWithFrame:self.view.bounds];
    self.decorateView.delegate = self;
    self.decorateView.parentViewController = self;
    [self.view addSubview:self.decorateView];
    
    
    [self startPlay];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBarHidden = YES;
    
//    if (self.rtmpURL) {
//        [self startRTMP];
//    }
//    
//    if (!_firstAppear) {
//        // 是否有摄像头权限
//        AVAuthorizationStatus cameraStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
//        if (cameraStatus == AVAuthorizationStatusDenied) {
//            return;
//        }
//        if (!_isPreviewing) {
//            [self.livePush startPreview:self.videoParentView];
//            _isPreviewing = YES;
//        }
//    } else {
//        _firstAppear = NO;
//    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.navigationController.navigationBarHidden = NO;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
//    [self stopRTMP];
}


#pragma mark - Override
 


#pragma mark - Methods

- (void)configVideoView {
    [self.livePlayer setupVideoWidget:self.view.frame containView:self.videoParentView insertIndex:0];
}

// 开始播放(拉流)
- (BOOL)startPlay {
    // 1. 判断拉流地址是否合法
    if (![self checkPlayURL:self.rtmpURL]) {
        return NO;
    }
   
    // 2. 检查拉流对象
    if (!self.livePlayer) {
        return NO;
    }
    self.livePlayer.delegate = self;
    int result = [self.livePlayer startPlay:self.rtmpURL type:_playType];
    if (-1 == result) {
        return NO;
    }
    if (0 != result) {
        NSLog(@"视频流播放失败, error: %d", result);
        return NO;
    }
    
    // 3. 关闭系统空闲定时器，保持屏幕常亮
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    return YES;
}

- (BOOL)startRTMP {
    [self configVideoView];
    return [self startPlay];
}

// 结束播放(拉流)
- (void)stopPlay {
    if (!self.livePlayer) {
        return;
    }
    self.livePlayer.delegate = nil;
    [self.livePlayer stopPlay];
    [self.livePlayer removeVideoWidget];
    
    // 恢复系统空闲定时器
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

// 显示观众端短视频录制界面
- (void)showPlayUGCDecorateView {
    self.decorateView.hidden = YES;
    
    // 隐藏状态栏
    [UIApplication sharedApplication].statusBarHidden = YES;
}

// 隐藏观众端短视频录制界面
- (void)hidePlayUGCDecorateView {
    self.decorateView.hidden = NO;
    
    // 显示状态栏
    [UIApplication sharedApplication].statusBarHidden = NO;
}


#pragma mark - BWPlayDecorateDelegate

// 退出播放页面
- (void)closePlayViewController {
    [self stopPlay];
    [self.navigationController popViewControllerAnimated:YES];
}

// 向主播点歌
- (void)clickOrderSong:(UIButton *)sender {
    NSLog(@"向主播点歌");
}

// 私信主播
- (void)clickPrivateMessage:(UIButton *)sender {
    PrivateMessageView *pmView = [[PrivateMessageView alloc] initWithFrame:CGRectMake(0, 0, WIDTH, HEIGHT)];
    [pmView showToView:self.view];
}

// 送主播礼物
- (void)clickGift:(UIButton *)sender {
    BWGiftView *giftView = [[BWGiftView alloc] initWithFrame:CGRectMake(0, 0, WIDTH, HEIGHT)];
    [giftView showToView:self.view];
}

// 录制主播视频
- (void)clickRecord:(UIButton *)sender {
    [self showPlayUGCDecorateView];
    
    self.recordUGCView = [[PlayUGCDecorateView alloc] initWithFrame:CGRectMake(0, 0, WIDTH, HEIGHT)];
    self.recordUGCView.delegate = self;
    [self.recordUGCView showToView:self.view];
}

// 分享主播
- (void)clickShare:(UIButton *)sender {
    BWPlayShareView *shareView = [[BWPlayShareView alloc] initWithFrame:CGRectMake(0, 0, WIDTH, HEIGHT)];
    [shareView showToView:self.view];
}


#pragma mark - PlayUGCDecorateViewDelegate

// 关闭短视频录制界面
- (void)closePlayUGCDecorateView {
    [self hidePlayUGCDecorateView];
    self.recordUGCView = nil;
}

// 开始录制短视频
- (void)recordVideoStart {
    int result = [self.livePlayer startRecord:RECORD_TYPE_STREAM_SOURCE];
    NSLog(@"开始录制: %d", result);
}

// 停止录制短视频
- (void)recordVideoStop {
    [self.livePlayer stopRecord];
}

// 重新录制短视频
- (void)recordVideoReset {
    [self.livePlayer stopRecord];
}


#pragma mark - Notification

// 在低系统（如7.1.2）可能收不到这个回调，请在onAppDidEnterBackGround和onAppWillEnterForeground里面处理打断逻辑
- (void)onAudioSessionEvent:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
//        if (_appIsInterrupt == NO) {
//            if (_playType == PLAY_TYPE_VOD_FLV || _playType == PLAY_TYPE_VOD_HLS || _playType == PLAY_TYPE_VOD_MP4) {
//                if (!_videoPause) {
//                    [self.livePlayer pause];
//                }
//            }
//            _appIsInterrupt = YES;
//        }
    } else {
        AVAudioSessionInterruptionOptions options = [info[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (options == AVAudioSessionInterruptionOptionShouldResume) {
//            if (_appIsInterrupt == YES) {
//                if (_playType == PLAY_TYPE_VOD_FLV || _playType == PLAY_TYPE_VOD_HLS || _playType == PLAY_TYPE_VOD_MP4) {
//                    if (!_videoPause) {
//                        [self.livePlayer resume];
//                    }
//                }
//                _appIsInterrupt = NO;
//            }
        }
    }
}

- (void)onAppDidEnterBackground:(UIApplication *)app {
//    if (_appIsInterrupt == NO) {
//        if (_playType == PLAY_TYPE_VOD_FLV || _playType == PLAY_TYPE_VOD_HLS || _playType == PLAY_TYPE_VOD_MP4) {
//            if (!_videoPause) {
//                [self.livePlayer pause];
//            }
//        }
//        _appIsInterrupt = YES;
//    }
}

- (void)onAppWillEnterForeground:(UIApplication *)app {
//    if (_appIsInterrupt == YES) {
//        if (_playType == PLAY_TYPE_VOD_FLV || _playType == PLAY_TYPE_VOD_HLS || _playType == PLAY_TYPE_VOD_MP4) {
//            if (!_videoPause) {
//                [self.livePlayer resume];
//            }
//        }
//        _appIsInterrupt = NO;
//    }
}


#pragma mark - TXLivePlayListener (拉流相关事件)

- (void)onPlayEvent:(int)EvtID withParam:(NSDictionary *)param {
    NSDictionary *paraDic = param;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (EvtID == PLAY_EVT_RCV_FIRST_I_FRAME) {
            
        } else if (EvtID == PLAY_EVT_PLAY_PROGRESS) {
            
        } else if (EvtID == PLAY_ERR_NET_DISCONNECT || EvtID == PLAY_EVT_PLAY_END) {
            [self stopPlay];
        } else if (EvtID == PLAY_EVT_PLAY_LOADING) {
            
        }
        
    });
    
    long long time = [(NSNumber *)[paraDic valueForKey:EVT_TIME] longLongValue];
    int mil = time % 1000;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:time / 1000];
    NSString *msg = (NSString *)[paraDic valueForKey:EVT_MSG];
    [self appendLog:msg time:date mills:mil];
}

- (void)onNetStatus:(NSDictionary *)param {
    NSDictionary *paraDic = param;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        int netspeed  = [(NSNumber *)[paraDic valueForKey:NET_STATUS_NET_SPEED] intValue];
        int vbitrate  = [(NSNumber *)[paraDic valueForKey:NET_STATUS_VIDEO_BITRATE] intValue];
        int abitrate  = [(NSNumber *)[paraDic valueForKey:NET_STATUS_AUDIO_BITRATE] intValue];
        int cachesize = [(NSNumber *)[paraDic valueForKey:NET_STATUS_CACHE_SIZE] intValue];
        int dropsize  = [(NSNumber *)[paraDic valueForKey:NET_STATUS_DROP_SIZE] intValue];
        int jitter    = [(NSNumber *)[paraDic valueForKey:NET_STATUS_NET_JITTER] intValue];
        int fps       = [(NSNumber *)[paraDic valueForKey:NET_STATUS_VIDEO_FPS] intValue];
        int width     = [(NSNumber *)[paraDic valueForKey:NET_STATUS_VIDEO_WIDTH] intValue];
        int height    = [(NSNumber *)[paraDic valueForKey:NET_STATUS_VIDEO_HEIGHT] intValue];
        float cpu_usage    = [(NSNumber *)[paraDic valueForKey:NET_STATUS_CPU_USAGE] floatValue];
        int codecCacheSize = [(NSNumber *)[paraDic valueForKey:NET_STATUS_CODEC_CACHE] intValue];
        int nCodecDropCnt  = [(NSNumber *)[paraDic valueForKey:NET_STATUS_CODEC_DROP_CNT] intValue];
        NSString *serverIP = [paraDic valueForKey:NET_STATUS_SERVER_IP];
        
        NSString *log = [NSString stringWithFormat:@"CPU:%.1f%%\tRES:%d*%d\tSPD:%dkb/s\nJITT:%d\tFPS:%d\tARA:%dkb/s\nQUE:%d|%d\tDRP:%d|%d\tVRA:%dkb/s\nSVR:%@\t",
                         cpu_usage * 100,
                         width,
                         height,
                         netspeed,
                         jitter,
                         fps,
                         abitrate,
                         codecCacheSize,
                         cachesize,
                         nCodecDropCnt,
                         dropsize,
                         vbitrate,
                         serverIP];
        NSLog(@"%@", log);
    });
}


#pragma mark - TXVideoRecordListener

- (void)onRecordProgress:(NSInteger)milliSecond {
    if (!self.recordUGCView) {
        return;
    }
    self.recordUGCView.recordDuration = (milliSecond / 1000);
}

- (void)onRecordComplete:(TXRecordResult *)result {
    if (result.retCode == RECORD_RESULT_FAILED || result.retCode == RECORD_RESULT_OK_INTERRUPT) {
        NSLog(@"录制失败: %@", result.descMsg);
    } else {
        NSLog(@"录制成功.");
    }
}


#pragma mark - Tool Methods 

- (BOOL)checkPlayURL:(NSString *)playURL {
    BOOL hasHTTP = [playURL hasPrefix:@"http:"];
    BOOL hasHTTPS = [playURL hasPrefix:@"https:"];
    BOOL hasRTMP = [playURL hasPrefix:@"rtmp:"];
    if (!(hasHTTP || hasHTTPS || hasRTMP)) {
        NSLog(@"播放地址不合法，目前仅支持rtmp / flv / hls / mp4播放格式！");
        return NO;
    }
    
    if (_isLivePlay) {
        if (hasRTMP) {
            _playType = PLAY_TYPE_LIVE_RTMP;
        } else if ((hasHTTP || hasHTTPS) && ([playURL rangeOfString:@".flv"].length > 0)) {
            _playType = PLAY_TYPE_LIVE_FLV;
        } else {
            NSLog(@"播放地址不合法，直播目前仅支持rtmp / flv播放格式！");
            return NO;
        }
    } else {
        if (hasHTTP || hasHTTPS) {
            if ([playURL rangeOfString:@".flv"].length > 0) {
                _playType = PLAY_TYPE_VOD_FLV;
            } else if ([playURL rangeOfString:@".m3u8"].length > 0) {
                _playType = PLAY_TYPE_VOD_HLS;
            } else if ([playURL rangeOfString:@".mp4"].length > 0) {
                _playType = PLAY_TYPE_VOD_MP4;
            } else {
                NSLog(@"播放地址不合法，点播目前仅支持flv / hls / mp4 播放格式！");
                return NO;
            }
        } else {
            NSLog(@"播放地址不合法，点播目前仅支持flv / hls / mp4 播放格式！");
            return NO;
        }
    }
    return YES;
}

- (void)appendLog:(NSString *)evt time:(NSDate *)date mills:(int)mil {
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss";
    NSString *time = [format stringFromDate:date];
    NSString *log = [NSString stringWithFormat:@"[%@.%-3.3d] %@", time, mil, evt];
    //    if (_logMsg == nil) {
    //        _logMsg = @"";
    //    }
    NSString *logMsg = [NSString stringWithFormat:@"%@", log];
    NSLog(@"%@", logMsg);
}

/**
 缩放图片

 @param image 原图片
 @param size 缩放后图片
 */
- (UIImage *)scaleImage:(UIImage *)image scaleToSize:(CGSize)size {
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

/**
 裁剪图片
 
 @param image 原图片
 @param rect 裁剪尺寸
 */
- (UIImage *)clipImage:(UIImage *)image inRect:(CGRect)rect {
    CGImageRef sourceImageRef = [image CGImage];
    CGImageRef newImageRef = CGImageCreateWithImageInRect(sourceImageRef, rect);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    CGImageRelease(newImageRef);
    return newImage;
}

/**
 创建高斯模糊效果图片
 */
- (UIImage *)gaussBlurImage:(UIImage *)image withGaussNumber:(CGFloat)blur {
    if (blur < 0 || blur > 1) {
        blur = 0.5;
    }
    int boxSize = (int)(blur * 40);
    boxSize = boxSize - (boxSize % 2) + 1;
    
    CGImageRef img = image.CGImage;
    vImage_Buffer inBuffer, outBuffer;
    vImage_Error error;
    
    void *pixelBuffer;
    // 从CGImage中获取数据
    CGDataProviderRef inProvider = CGImageGetDataProvider(img);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    // 设置从CGImage获取对象的属性
    inBuffer.width = CGImageGetWidth(img);
    inBuffer.height = CGImageGetHeight(img);
    inBuffer.rowBytes = CGImageGetBytesPerRow(img);
    inBuffer.data = (void *)CFDataGetBytePtr(inBitmapData);
    pixelBuffer = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img));
    if (pixelBuffer == NULL) {
        NSLog(@"No pixel buffer.");
    }
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(img);
    outBuffer.height = CGImageGetHeight(img);
    outBuffer.rowBytes = CGImageGetBytesPerRow(img);
    error = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    if (error) {
        NSLog(@"error from convolution %ld", error);
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(outBuffer.data, outBuffer.width, outBuffer.height, 8, outBuffer.rowBytes, colorSpace, kCGImageAlphaNoneSkipLast);
    CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
    UIImage *gaussBlurImage = [UIImage imageWithCGImage:imageRef];
    
    // Clean up
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    free(pixelBuffer);
    CFRelease(inBitmapData);
//    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageRef);
    
    return gaussBlurImage;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
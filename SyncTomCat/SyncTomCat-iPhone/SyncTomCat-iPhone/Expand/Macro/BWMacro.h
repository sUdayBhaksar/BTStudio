//
//  BWMacro.h
//  SyncTomCat
//
//  Created by  Wangzhi on 2017/7/18.
//  Copyright © 2017年 BTStudio. All rights reserved.
//

#ifndef BWMacro_h
#define BWMacro_h


#pragma mark - NSLog

#ifndef __OPTIMIZE__  // 如果release状态就不执行NSLog函数
//#define NSLog(...) printf("%s [%s:%d] %s\n", [[NSString stringWithFormat:@"%@", [[NSDate date] dateByAddingTimeInterval:[[NSTimeZone systemTimeZone] secondsFromGMTForDate:[NSDate date]]]] UTF8String], [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __LINE__, [[NSString stringWithFormat:__VA_ARGS__] UTF8String]);
#else
#define NSLog(...) {}
#endif


#pragma mark - 设备屏幕宽高/类型/屏幕类型/适配比例

// 屏幕宽高
#define WIDTH [UIScreen mainScreen].bounds.size.width
#define HEIGHT [UIScreen mainScreen].bounds.size.height

#define SCREEN_MAX_LENGTH (MAX(WIDTH, HEIGHT))
#define SCREEN_MIN_LENGTH (MIN(WIDTH, HEIGHT))

// 设备类型
#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_RETINA ([[UIScreen mainScreen] scale] >= 2.0)

// 屏幕类型
#define IS_IPHONE_4_OR_LESS (IS_IPHONE && SCREEN_MAX_LENGTH < 568.0)
#define IS_IPHONE_5 (IS_IPHONE && SCREEN_MAX_LENGTH == 568.0)
#define IS_IPHONE_6 (IS_IPHONE && SCREEN_MAX_LENGTH == 667.0)
#define IS_IPHONE_6P (IS_IPHONE && SCREEN_MAX_LENGTH == 736.0)


#pragma mark - 弱引用

#define BRIAN_WEAK_SELF __weak typeof(self) weakSelf = self;


#pragma mark - 颜色

#define RGBA(r, g, b, a) [UIColor colorWithRed:(r) / 255.0f green:(g) / 255.0f blue:(b) / 255.0f alpha:(a)]
#define RGB(red, green, blue) RGBA(red, green, blue, 1.0f)


#pragma mark - 单例创建的宏 (Singleton Pattern)

// .h文件
// \代表下一行也属于宏, ##是分隔符
//#define SINGLETON_INTERFACE(class) + (class *)shared##class;
#define SINGLETON_INTERFACE(class) + (instancetype)sharedInstance;

#if __has_feature(objc_arc)
// .m文件
#define SINGLETON_IMPLEMENTATION(class) \
static class *_instance; \
\
+ (id)allocWithZone:(struct _NSZone *)zone { \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        _instance = [super allocWithZone:zone]; \
    }); \
    return _instance; \
} \
\
+ (instancetype)sharedInstance { \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        _instance = [[self alloc] init]; \
    }); \
    return _instance; \
} \
\
- (id)copyWithZone:(NSZone *)zone { \
    return _instance; \
}

#else

#define SINGLETON_IMPLEMENTATION(class) \
static class *_instance; \
\
+ (id)allocWithZone:(struct _NSZone *)zone { \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        _instance = [super allocWithZone:zone]; \
    }); \
    return _instance; \
} \
\
+ (instancetype)sharedInstance { \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        _instance = [[self alloc] init]; \
    }); \
    return _instance; \
} \
\
- (id)copyWithZone:(NSZone *)zone { \
    return _instance; \
} \
\
- (oneway void)release { \
} \
\
- (id)retain { \
    return self; \
} \
\
- (NSUInteger)retainCount { \
    return 1; \
} \
\
- (id)autorelease { \
    return self; \
}

#endif


#pragma mark - 头文件导入 

#import "BWConst.h" // 常量
#import "NSString+BrianExtension.h" // 字符串扩展分类



#endif /* BWMacro_h */

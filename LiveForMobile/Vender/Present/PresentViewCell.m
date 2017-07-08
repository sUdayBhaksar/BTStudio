//
//  PresentViewCell.m
//  PresentDemo
//
//  Created by 阮思平 on 16/10/2.
//  Copyright © 2016年 阮思平. All rights reserved.
//

#import "PresentViewCell.h"

#define Duration 0.3

@interface PresentViewCell ()

@property (weak, nonatomic) PresentLabel *shakeLable;

/**
 *  记录礼物连乘数
 */
@property (assign, nonatomic) NSInteger number;

/**
 *  记录cell最初始的frame(即开始展示动画前的frame)
 */
@property (assign, nonatomic) CGRect originalFrame;

/**
 *  shake动画的缓存数组
 */
@property (strong, nonatomic) NSMutableArray *caches;

/**
 *  shake动画模型的缓存数组
 */
@property (strong, nonatomic) NSMutableArray *modelCaches;

@end

@implementation PresentViewCell

#pragma mark - Setter/Getter

- (NSMutableArray *)caches {
    if (!_caches) {
        _caches = [NSMutableArray array];
    }
    return _caches;
}

- (NSMutableArray *)modelCaches {
    if (!_modelCaches) {
        _modelCaches = [NSMutableArray array];
    }
    return _modelCaches;
}


#pragma mark - Initial

- (instancetype)initWithRow:(NSInteger)row {
    if (self = [super init]) {
        _row = row;
        _state = AnimationStateNone;
    }
    return self;
}


#pragma mark - Private

/**
 *  添加连乘lable
 */
- (void)addShakeLabel {
    PresentLabel *label   = [[PresentLabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.borderColor     = [UIColor colorWithRed:159 / 255.0 green:110 / 255.0 blue:4 / 255.0 alpha:1.0];
    label.textColor       = [UIColor colorWithRed:254 / 255.0 green:209 / 255.0 blue:74 / 255.0 alpha:1.0];
    label.font            = [UIFont systemFontOfSize:20.0];
    label.textAlignment   = NSTextAlignmentCenter;
    label.alpha           = 0.0;
    CGFloat w             = 60;
    CGFloat h             = 22;
    CGFloat x             = CGRectGetWidth(self.frame) - 10;
    CGFloat y             = - h + 10;
    label.frame           = CGRectMake(x, y, w, h);
    self.shakeLable       = label;
    [self addSubview:label];
}

/**
 *  开始连乘动画(利用递归实现连乘动画)
 *
 *  @param number 连乘次数
 *  @param block  当前number次连乘动画执行完成回调
 */
- (void)startShakeAnimationWithNumber:(NSInteger)number completion:(void (^)(BOOL finished))block {
    self.superview.userInteractionEnabled = YES;
    _state                 = AnimationStateShaking;
    self.shakeLable.text   = [NSString stringWithFormat:@"x %ld", ++self.number];
    __weak typeof(self) ws = self;
    [self.shakeLable startAnimationDuration:Duration completion:^(BOOL finish) {
        if (number > 1) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [ws startShakeAnimationWithNumber:(number - 1) completion:block];
            });
        } else {
            _state = AnimationStateShaked;
            if (block) {
                block(YES);
            }
        }
    }];
}


#pragma mark - Public

- (void)showAnimationWithModel:(id<PresentModelAble>)model showShakeAnimation:(BOOL)flag prepare:(void (^)(void))prepare completion:(void (^)(BOOL))completion {
    _state             = AnimationStateShowing;
    _baseModel         = model;
    _sender            = [model sender];
    _giftName          = [model giftName];
    self.originalFrame = self.frame;
    self.number        = 0;
    if (prepare) {
        prepare();
    }
    [UIView animateWithDuration:Duration delay:0 usingSpringWithDamping:1.0 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        [self customDisplayAnimationOfShowShakeAnimation:flag];
    } completion:^(BOOL finished) {
        if (flag) {
            if (!self.shakeLable) {
                [self addShakeLabel];
            }
            self.shakeLable.alpha = 1.0;
        }
        if (completion) {
            completion(flag);
        }
    }];
}

- (void)shakeAnimationWithNumber:(NSInteger)number {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hiddenAnimationOfShowShake:) object:@(YES)];
    [self performSelector:@selector(hiddenAnimationOfShowShake:) withObject:@(YES) afterDelay:self.showTime];
    if (number > 0) {
        [self.caches addObject:@(number)];
    }
    if (self.caches.count > 0 && _state != AnimationStateShaking) {
        NSInteger cache        = [self.caches.firstObject integerValue];
        [self.caches removeObjectAtIndex:0]; // 不能删除对象，因为可能有相同的对象
        __weak typeof(self) ws = self;
        [self startShakeAnimationWithNumber:cache completion:^(BOOL finished) {
            [ws shakeAnimationWithNumber:-1]; // 传-1是为了缓存不被重复添加
        }];
    }
}

- (void)shakeAnimationWithModels:(NSArray<id<PresentModelAble>> *)models {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hiddenAnimationOfShowShake:) object:@(YES)];
    [self performSelector:@selector(hiddenAnimationOfShowShake:) withObject:@(YES) afterDelay:self.showTime];
    if (models.count > 0) [self.modelCaches addObjectsFromArray:models];
    if (self.modelCaches.count > 0 && _state != AnimationStateShaking) {
        _state = AnimationStateShaking;
        id<PresentModelAble> obj = self.modelCaches.firstObject;
        self.shakeLable.text = [NSString stringWithFormat:@"x %ld", [obj giftNumber]];
        [self.modelCaches removeObjectAtIndex:0];
        __weak typeof(self) ws = self;
        [self.shakeLable startAnimationDuration:Duration completion:^(BOOL finish) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                _state = AnimationStateShaked;
                if (ws.modelCaches.count > 0) {
                    [ws shakeAnimationWithModels:nil];
                }
            });
        }];
    }
}

- (void)hiddenAnimationOfShowShake:(BOOL)flag {
    self.superview.userInteractionEnabled = NO;
    _state = AnimationStateHiding;
    [UIView animateWithDuration:Duration delay:0 usingSpringWithDamping:1.0 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        [self customHideAnimationOfShowShakeAnimation:flag];
    } completion:^(BOOL finished) {
        // 恢复cell的初始状态
        self.frame            = self.originalFrame;
        _state                = AnimationStateNone;
        self.shakeLable.alpha = 0.0;
        [self.caches removeAllObjects];
        [self.modelCaches removeAllObjects];
        
        // 通知代理
        if ([self.delegate respondsToSelector:@selector(presentViewCell:showShakeAnimation:shakeNumber:)]) {
            [self.delegate presentViewCell:self showShakeAnimation:flag shakeNumber:self.number];
        }
    }];
}

// 目前还没有使用
- (void)releaseVariable {
//    [self.shakeLable removeFromSuperview];
}

@end


@implementation PresentViewCell (OverWrite)

- (void)customDisplayAnimationOfShowShakeAnimation:(BOOL)flag {
    self.alpha     = 1.0;
    CGRect selfF   = self.frame;
    selfF.origin.x = 0;
    self.frame     = selfF;
}

- (void)customHideAnimationOfShowShakeAnimation:(BOOL)flag {
    self.alpha     = 0.0;
    CGRect selfF   = self.frame;
    selfF.origin.y -= (CGRectGetHeight(selfF) * 0.5);
    self.frame     = selfF;
}

@end


@implementation PresentLabel

- (void)drawTextInRect:(CGRect)rect {
    UIColor *textColor = self.textColor;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 2); // 描边的宽度
    CGContextSetLineJoin(context, kCGLineJoinRound);
    
    CGContextSetTextDrawingMode(context, kCGTextStroke);
    self.textColor = self.borderColor;
    [super drawTextInRect:rect];
    
    CGContextSetTextDrawingMode(context, kCGTextFill);
    self.textColor = textColor;
    self.shadowOffset = CGSizeMake(0, 0);
    [super drawTextInRect:rect];
}

- (void)startAnimationDuration:(NSTimeInterval)interval completion:(void (^)(BOOL finish))completion {
    [UIView animateKeyframesWithDuration:interval delay:0 options:0 animations:^{
        
        [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:1 / 2.0 animations:^{
            self.transform = CGAffineTransformMakeScale(3, 3);
        }];
        [UIView addKeyframeWithRelativeStartTime:1 / 2.0 relativeDuration:1 / 2.0 animations:^{
            self.transform = CGAffineTransformMakeScale(0.8, 0.8);
        }];
        
    } completion:^(BOOL finished) {
        
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.4 initialSpringVelocity:10 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            if (completion) {
                completion(finished);
            }
        }];
    }];
}

@end


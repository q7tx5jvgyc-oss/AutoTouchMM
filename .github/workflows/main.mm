#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface MoustacheManager : NSObject
@end

@implementation MoustacheManager
+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = [UIApplication sharedApplication].keyWindow;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(100, 100, 60, 60);
        btn.backgroundColor = [UIColor redColor];
        [btn setTitle:@"Auto" forState:UIControlStateNormal];
        [win addSubview:btn];
    });
}
@end

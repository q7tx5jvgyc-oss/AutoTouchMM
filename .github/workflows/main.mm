#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// إعلان خارجي للوظائف اللمسية الخاصة بنظام iOS لمحاكاة نقرات فيزيائية حقيقية
extern "C" void IOHIDEventCreateDigitizerEvent(); 

static BOOL isAutoTouchRunning = NO;
static NSTimeInterval touchInterval = 1.0;
static dispatch_queue_t autoTouchQueue = nil;
static NSMutableArray *touchPointsArray = nil;

@interface AutotouhWebWindow : UIWindow <WKScriptMessageHandler>
@property (nonatomic, strong) WKWebView *webView;
@end

@implementation AutotouhWebWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        autoTouchQueue = dispatch_queue_create("com.autotouh.engine", DISPATCH_QUEUE_SERIAL);
        touchPointsArray = [[NSMutableArray alloc] init];
        
        // النقطة الافتراضية الأولى في منتصف الشاشة
        CGPoint centerPoint = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, [UIScreen mainScreen].bounds.size.height / 2);
        [touchPointsArray addObject:[NSValue valueWithCGPoint:centerPoint]];

        self.windowLevel = UIWindowLevelAlert + 10.0;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = NO;

        [self setupWebViewMenu];
    }
    return self;
}

// دالة لتمرير اللمس للعبة الخلفية عندما تكون واجهة الويب شفافة
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.webView) {
        return nil; 
    }
    return hitView;
}

- (void)setupWebViewMenu {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    // إنشاء مستمع لقراءة الرسائل القادمة من سكريبت الـ HTML
    [config.userContentController addScriptMessageHandler:self name:@"AutotouhBridge"];

    self.webView = [[WKWebView alloc] initWithFrame:[UIScreen mainScreen].bounds configuration:config];
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.opaque = NO;
    
    // منع التمرير والارتداد داخل الويب لتظهر كقائمة نظام أصلية
    self.webView.scrollView.scrollEnabled = NO;
    self.webView.scrollView.bounces = NO;

    // دمج كود الـ HTML والميزات المتقدمة بداخل ملف الـ dylib مباشرة
    NSString *htmlSource = @"\
    <!DOCTYPE html>\
    <html>\
    <head>\
        <meta charset='UTF-8'>\
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>\
        <style>\
            html, body { margin:0; padding:0; width:100vw; height:100vh; background:transparent; font-family:sans-serif; overflow:hidden; user-select:none; }\
            #floating-btn { position:fixed; top:20%; left:20px; width:55px; height:55px; background:linear-gradient(135deg, #007aff, #0051a8); color:#fff; border-radius:50%; display:flex; align-items:center; justify-content:center; font-weight:bold; font-size:13px; box-shadow:0 4px 12px rgba(0,0,0,0.6); z-index:99999; touch-action:none; }\
            #menu-container { position:fixed; top:50%; left:50%; transform:translate(-50%, -50%); width:300px; background:rgba(20,20,25,0.98); border:1px solid rgba(255,255,255,0.15); border-radius:12px; padding:15px; box-shadow:0 15px 35px rgba(0,0,0,0.8); display:none; z-index:99998; text-align:center; box-sizing:border-box; color:#fff; }\
            h3 { margin:0 0 15px 0; font-size:16px; padding-bottom:8px; border-bottom:1px solid rgba(255,255,255,0.1); }\
            .control-group { display:flex; justify-content:space-between; margin-bottom:12px; }\
            .btn { width:48%; padding:10px 0; border:none; border-radius:8px; font-weight:bold; font-size:14px; color:#fff; }\
            #start-btn { background:#34c759; }\
            #stop-btn { background:#ff3b30; }\
            .action-btn { width:100%; color:#fff; border:none; padding:9px; border-radius:6px; font-weight:bold; margin-bottom:6px; font-size:13px; background:#5856d6; }\
            .points-list { max-height:80px; overflow-y:auto; font-size:12px; color:#ccc; padding:0; margin:5px 0 0 0; list-style:none; text-align:right; }\
            .slider-section { margin-top:5px; background:rgba(255,255,255,0.02); padding:8px; border-radius:8px; }\
            .slider-label { display:block; font-size:12px; color:#b3b3b3; margin-bottom:6px; }\
            .slider { width:100%; -webkit-appearance:none; height:6px; background:#3a3a3c; border-radius:3px; outline:none; }\
            .slider::-webkit-slider-thumb { -webkit-appearance:none; width:18px; height:18px; border-radius:50%; background:#007aff; }\
        </style>\
    </head>\
    <body>\
        <div id='floating-btn'>Menu</div>\
        <div id='menu-container'>\
            <h3>Autotouh Dylib Menu</h3>\
            <div class='control-group'>\
                <button id='start-btn' class='btn' onclick='sendAction(\"start\")'>تشغيل</button>\
                <button id='stop-btn' class='btn' onclick='sendAction(\"stop\")'>إيقاف</button>\
            </div>\
            <div style='background:rgba(255,255,255,0.04); padding:10px; border-radius:8px; margin-bottom:12px;'>\
                <button class='action-btn' onclick='sendAction(\"addPoint\")'>➕ إضافة نقطة (منتصف الشاشة)</button>\
                <ul id='points-display' class='points-list'>\
                    <li>• نقطة 1: منتصف الشاشة</li>\
                </ul>\
            </div>\
            <div class='slider-section'>\
                <span id='speed-lbl' class='slider-label'>معدل السرعة: 1.00 ثانية</span>\
                <input type='range' min='0.01' max='3.00' step='0.01' value='1.00' class='slider' oninput='updateSpeed(this.value)'>\
            </div>\
        </div>\
        <script>\
            const btn = document.getElementById('floating-btn');\
            const menu = document.getElementById('menu-container');\
            let drag = false;\
            \
            btn.addEventListener('click', () => {\
                if(drag) return;\
                menu.style.display = menu.style.display === 'block' ? 'none' : 'block';\
            });\
            \
            function sendAction(actionName) {\
                window.webkit.messageHandlers.AutotouhBridge.postMessage({action: actionName});\
            }\
            \
            function updateSpeed(val) {\
                document.getElementById('speed-lbl').innerText = 'معدل السرعة: ' + parseFloat(val).toFixed(2) + ' ثانية';\
                window.webkit.messageHandlers.AutotouhBridge.postMessage({action: 'speed', value: parseFloat(val)});\
            }\
            \
            let isDragging = false, startX, startY, initialLeft, initialTop;\
            btn.addEventListener('touchstart', (e) => {\
                isDragging = true; drag = false;\
                startX = e.touches[0].clientX; startY = e.touches[0].clientY;\
                initialLeft = btn.offsetLeft; initialTop = btn.offsetTop;\
            });\
            btn.addEventListener('touchmove', (e) => {\
                if(!isDragging) return; drag = true;\
                let moveX = initialLeft + (e.touches[0].clientX - startX);\
                let moveY = initialTop + (e.touches[0].clientY - startY);\
                btn.style.left = Math.max(0, Math.min(window.innerWidth-55, moveX)) + 'px';\
                btn.style.top = Math.max(0, Math.min(window.innerHeight-55, moveY)) + 'px';\
            });\
            btn.addEventListener('touchend', () => { isDragging = false; });\
            \
            window.addEventListener('touchstart', (e) => {\
                if (e.touches.length === 3) {\
                    btn.style.display = btn.style.display === 'none' ? 'flex' : 'none';\
                    menu.style.display = 'none';\
                }\
            });\
        </script>\
    </body>\
    </html>";

    [self.webView loadHTMLString:htmlSource baseURL:nil];
    [self addSubview:self.webView];
}

#pragma mark - جسر مراسلة الويب واستقبال الأوامر من السكريبت
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSDictionary *body = message.body;
    NSString *action = body[@"action"];

    if ([action isEqualToString:@"start"]) {
        [self startAutoTouchEngine];
    } else if ([action isEqualToString:@"stop"]) {
        [self stopAutoTouchEngine];
    } else if ([action isEqualToString:@"addPoint"]) {
        CGRect screenRect = [UIScreen mainScreen].bounds;
        CGPoint centralPoint = CGPointMake(screenRect.size.width / 2, screenRect.size.height / 2);
        [touchPointsArray addObject:[NSValue valueWithCGPoint:centralPoint]];
    } else if ([action isEqualToString:@"speed"]) {
        NSNumber *value = body[@"value"];
        touchInterval = [value doubleValue];
    }
}

#pragma mark - محرك حقن اللمس المتكرر بالخلفية بدون تعليق اللعبة
- (void)startAutoTouchEngine {
    if (isAutoTouchRunning) return;
    isAutoTouchRunning = YES;

    dispatch_async(autoTouchQueue, ^{
        while (isAutoTouchRunning) {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSValue *value in touchPointsArray) {
                    CGPoint targetPoint = [value CGPointValue];
                    [self simulatePhysicalTouchAtPoint:targetPoint];
                }
            });
            [NSThread sleepForTimeInterval:touchInterval];
        }
    });
}

- (void)stopAutoTouchEngine {
    isAutoTouchRunning = NO;
}

// دالة المحاكاة الحقيقية لأحداث اللمس الفيزيائية على نظام iOS من داخل الـ dylib
- (void)simulatePhysicalTouchAtPoint:(CGPoint)point {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow && window != self) {

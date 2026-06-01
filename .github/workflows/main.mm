#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

// ==========================================
// 1. تصميم الأهداف المتعددة المرقمة القابلة للحركة
// ==========================================
@interface MustacheTargetNode : UIView
@property (nonatomic, assign) CGPoint screenAbsolutePoint; 
@property (nonatomic, strong) UILabel *numberLabel;
@end

@implementation MustacheTargetNode
- (instancetype)initWithFrame:(CGRect)frame index:(NSInteger)index {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.80];
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.layer.borderWidth = 2.0;
        self.userInteractionEnabled = YES;
        
        self.numberLabel = [[UILabel alloc] initWithFrame:self.bounds];
        self.numberLabel.text = [NSString stringWithFormat:@"%ld", (long)index];
        self.numberLabel.textColor = [UIColor whiteColor];
        self.numberLabel.textAlignment = NSTextAlignmentCenter;
        self.numberLabel.font = [UIFont boldSystemFontOfSize:14];
        [self addSubview:self.numberLabel];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleNodePan:)];
        [self addGestureRecognizer:pan];
        
        [self updateAbsolutePosition];
    }
    return self;
}

- (void)handleNodePan:(UIPanGestureRecognizer *)sender {
    CGPoint translation = [sender translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [sender setTranslation:CGPointMake(0, 0) inView:self.superview];
    
    if (sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateChanged) {
        [self updateAbsolutePosition];
    }
}

- (void)updateAbsolutePosition {
    // تسجيل موقع الهدف مباشرة بالنسبة للنافذة الأصلية للعبة
    self.screenAbsolutePoint = self.center;
}
@end

// ==========================================
// 2. إدارة لوحة التحكم وحقنها في نافذة اللعبة مباشرة (تمنع الفريز 100%)
// ==========================================
@interface MustacheLudoController : NSObject
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) NSMutableArray<MustacheTargetNode *> *targetsArray;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) float interval;
@property (nonatomic, strong) dispatch_source_t clickTimer;
+ (instancetype)sharedInstance;
- (void)initMenuInsideGame;
@end

@implementation MustacheLudoController

+ (instancetype)sharedInstance {
    static MustacheLudoController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.targetsArray = [[NSMutableArray alloc] init];
        self.interval = 0.10;
        self.isRunning = NO;
    }
    return self;
}

- (void)initMenuInsideGame {
    // جلب النافذة الحقيقية للعبة لودو لحقن العناصر بداخلها مباشرة
    UIWindow *gameWindow = [UIApplication sharedApplication].keyWindow;
    if (!gameWindow && @available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                gameWindow = scene.windows.firstObject;
                break;
            }
        }
    }
    if (!gameWindow) return;

    // إنشاء الزر العائم مباشرة داخل اللعبة
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(40, 200, 75, 45);
    self.floatingButton.backgroundColor = [UIColor blackColor];
    [self.floatingButton setTitle:@"موستاش" forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    self.floatingButton.layer.cornerRadius = 12;
    self.floatingButton.layer.borderWidth = 2.0;
    self.floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleButtonPan:)];
    [self.floatingButton addGestureRecognizer:pan];
    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [gameWindow addSubview:self.floatingButton];
    
    // إنشاء القائمة مباشرة داخل اللعبة
    self.menuContainer = [[UIView alloc] initWithFrame:CGRectMake(40, 255, 250, 260)];
    self.menuContainer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.96];
    self.menuContainer.layer.cornerRadius = 15;
    self.menuContainer.layer.borderColor = [UIColor whiteColor].CGColor;
    self.menuContainer.layer.borderWidth = 2.0;
    self.menuContainer.hidden = YES;
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 230, 25)];
    title.text = @"MUSTACHE AUTO MENU";
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:13];
    [self.menuContainer addSubview:title];
    
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    addBtn.frame = CGRectMake(25, 45, 200, 34);
    addBtn.backgroundColor = [UIColor whiteColor];
    [addBtn setTitle:@"➕ اضافه هدف" forState:UIControlStateNormal];
    [addBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    addBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    addBtn.layer.cornerRadius = 8;
    [addBtn addTarget:self action:@selector(addTargetNode) forControlEvents:UIControlEventTouchUpInside];
    [self.menuContainer addSubview:addBtn];
    
    UIButton *removeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    removeBtn.frame = CGRectMake(25, 85, 200, 34);
    removeBtn.backgroundColor = [UIColor redColor];
    [removeBtn setTitle:@"❌ حذف آخر هدف" forState:UIControlStateNormal];
    [removeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    removeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    removeBtn.layer.cornerRadius = 8;
    [removeBtn addTarget:self action:@selector(removeLastNode) forControlEvents:UIControlEventTouchUpInside];
    [self.menuContainer addSubview:removeBtn];
    
    self.speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(25, 135, 200, 30)];
    self.speedSlider.minimumValue = 0.02;
    self.speedSlider.maximumValue = 1.5;
    self.speedSlider.value = 0.10;
    self.speedSlider.tintColor = [UIColor whiteColor];
    [self.speedSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuContainer addSubview:self.speedSlider];
    
    self.speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 165, 230, 20)];
    self.speedLabel.text = @"معدل النقر: 0.10 ثانية";
    self.speedLabel.textColor = [UIColor lightGrayColor];
    self.speedLabel.textAlignment = NSTextAlignmentCenter;
    self.speedLabel.font = [UIFont systemFontOfSize:11];
    [self.menuContainer addSubview:self.speedLabel];
    
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleButton.frame = CGRectMake(25, 205, 200, 42);
    self.toggleButton.backgroundColor = [UIColor whiteColor];
    [self.toggleButton setTitle:@"▶️ تشغيل التلقائي" forState:UIControlStateNormal];
    [self.toggleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.toggleButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.toggleButton.layer.cornerRadius = 10;
    [self.toggleButton addTarget:self action:@selector(toggleMacroState) forControlEvents:UIControlEventTouchUpInside];
    [self.menuContainer addSubview:self.toggleButton];
    
    [gameWindow addSubview:self.menuContainer];
}

- (void)handleButtonPan:(UIPanGestureRecognizer *)sender {
    UIWindow *gameWindow = [UIApplication sharedApplication].keyWindow;
    CGPoint translation = [sender translationInView:gameWindow];
    sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y + translation.y);
    [sender setTranslation:CGPointMake(0, 0) inView:gameWindow];
}

- (void)toggleMenu {
    self.menuContainer.hidden = !self.menuContainer.hidden;
}

- (void)addTargetNode {
    UIWindow *gameWindow = [UIApplication sharedApplication].keyWindow;
    NSInteger nextIndex = self.targetsArray.count + 1;
    MustacheTargetNode *node = [[MustacheTargetNode alloc] initWithFrame:CGRectMake(150, 350, 36, 36) index:nextIndex];
    [gameWindow addSubview:node];
    [self.targetsArray addObject:node];
}

- (void)removeLastNode {
    if (self.targetsArray.count > 0) {
        MustacheTargetNode *lastNode = self.targetsArray.lastObject;
        [lastNode removeFromSuperview];
        [self.targetsArray removeLastObject];
    }
}

- (void)sliderChanged:(UISlider *)sender {
    self.interval = sender.value;
    self.speedLabel.text = [NSString stringWithFormat:@"معدل النقر: %.3f ثانية", sender.value];
    if (self.isRunning) {
        [self stopTimer];
        [self startTimer];
    }
}

- (void)toggleMacroState {
    if (self.isRunning) {
        [self stopTimer];
        [self.toggleButton setTitle:@"▶️ تشغيل التلقائي" forState:UIControlStateNormal];
        self.toggleButton.backgroundColor = [UIColor whiteColor];
        [self.toggleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    } else {

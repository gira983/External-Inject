#import "esp.h"
#import "cfg.h"
#include "obfusheader.h"
#import "tt.h"
#import "../../sources/UIView+SecureView.h"
#import <objc/runtime.h>

// ─── CustomSliderView ─────────────────────────────────────────────────────────
@interface CustomSliderView : UIView
@property (nonatomic, assign) float value;
@property (nonatomic, assign) float minValue;
@property (nonatomic, assign) float maxValue;
@property (nonatomic, copy) void (^valueChanged)(float newValue);
- (instancetype)initWithFrame:(CGRect)frame min:(float)min max:(float)max current:(float)current;
@end

@implementation CustomSliderView { UIView *_track; UIView *_thumb; }
- (instancetype)initWithFrame:(CGRect)frame min:(float)min max:(float)max current:(float)current {
    self = [super initWithFrame:frame];
    if (self) {
        _minValue = min; _maxValue = max; _value = current;
        _track = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height/2-1, frame.size.width, 2)];
        _track.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
        _track.userInteractionEnabled = NO;
        [self addSubview:_track];
        _thumb = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,12)];
        _thumb.backgroundColor = [UIColor whiteColor];
        _thumb.layer.cornerRadius = 6;
        _thumb.userInteractionEnabled = NO;
        [self addSubview:_thumb];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)]];
        [self updateThumbPosition];
    }
    return self;
}
- (void)handlePan:(UIPanGestureRecognizer *)g { [self updateValueWithX:[g locationInView:self].x]; }
- (void)handleTap:(UITapGestureRecognizer *)g { [self updateValueWithX:[g locationInView:self].x]; }
- (void)updateValueWithX:(CGFloat)x {
    float p = fmaxf(0, fminf(1, x / self.frame.size.width));
    _value = _minValue + (_maxValue - _minValue) * p;
    [self updateThumbPosition];
    if (self.valueChanged) self.valueChanged(_value);
}
- (void)updateThumbPosition {
    float p = (_value - _minValue) / (_maxValue - _minValue);
    _thumb.center = CGPointMake(self.frame.size.width * p, self.frame.size.height/2);
}
- (void)setValue:(float)value { _value = value; [self updateThumbPosition]; }
@end

// ─── CustomSegmentedControl ───────────────────────────────────────────────────
@interface CustomSegmentedControl : UIView
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) void (^valueChanged)(NSInteger newIndex);
- (instancetype)initWithFrame:(CGRect)frame items:(NSArray *)items current:(NSInteger)current;
- (void)reloadUI:(NSInteger)idx;
@end

@implementation CustomSegmentedControl { NSArray *_items; NSMutableArray *_labels; }
- (instancetype)initWithFrame:(CGRect)frame items:(NSArray *)items current:(NSInteger)current {
    self = [super initWithFrame:frame];
    if (self) {
        _items = items; _selectedIndex = current; _labels = [NSMutableArray new];
        self.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        self.layer.cornerRadius = 6; self.clipsToBounds = YES;
        CGFloat bw = frame.size.width / items.count;
        for (int i = 0; i < (int)items.count; i++) {
            UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(i*bw,0,bw,frame.size.height)];
            l.text = items[i]; l.textAlignment = NSTextAlignmentCenter;
            BOOL sel = (i == current);
            l.font = [UIFont systemFontOfSize:10 weight:sel ? UIFontWeightBold : UIFontWeightRegular];
            l.textColor = sel ? [UIColor blackColor] : [UIColor colorWithWhite:0.7 alpha:1];
            l.backgroundColor = sel ? [UIColor whiteColor] : [UIColor clearColor];
            [self addSubview:l]; [_labels addObject:l];
        }
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)]];
    }
    return self;
}
- (void)reloadUI:(NSInteger)idx {
    if (idx < 0) idx = 0; if (idx >= (NSInteger)_items.count) idx = _items.count-1;
    _selectedIndex = idx;
    for (int i = 0; i < (int)_labels.count; i++) {
        UILabel *l = _labels[i]; BOOL sel = (i == idx);
        l.textColor = sel ? [UIColor blackColor] : [UIColor colorWithWhite:0.7 alpha:1];
        l.backgroundColor = sel ? [UIColor whiteColor] : [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:10 weight:sel ? UIFontWeightBold : UIFontWeightRegular];
    }
}
- (void)handleTap:(UITapGestureRecognizer *)g {
    NSInteger idx = [g locationInView:self].x / (self.frame.size.width / _items.count);
    if (idx < 0) idx = 0; if (idx >= (NSInteger)_items.count) idx = _items.count-1;
    [self reloadUI:idx];
    if (self.valueChanged) self.valueChanged(idx);
}
@end

// ─── VerticalOnlyPanGestureRecognizer ─────────────────────────────────────────
@interface VerticalOnlyPanGestureRecognizer : UIPanGestureRecognizer @end
@implementation VerticalOnlyPanGestureRecognizer
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UIView *v = touches.anyObject.view;
    while (v) {
        if ([v isKindOfClass:[CustomSegmentedControl class]] || [v isKindOfClass:[CustomSliderView class]])
            { self.state = UIGestureRecognizerStateFailed; return; }
        v = v.superview;
    }
    [super touchesBegan:touches withEvent:event];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    if (self.state == UIGestureRecognizerStateBegan) {
        CGPoint vel = [self velocityInView:self.view];
        if (fabs(vel.x) > fabs(vel.y)) self.state = UIGestureRecognizerStateFailed;
    }
}
@end

// ─── MenuView ─────────────────────────────────────────────────────────────────
@interface MenuView () <UIGestureRecognizerDelegate> @end

@implementation MenuView {
    UIVisualEffectView *_blurView;
    UIView             *_headerView;
    UILabel            *_headerLabel;
    UIView             *_contentView;
    UIView             *_leftBarView;
    NSMutableArray<UILabel *> *_tabLabels;
    CGPoint             _initialTouchPoint;
    BOOL                _collapsed;
    CAShapeLayer       *_arrowLayer;

    // Tab containers
    UIView *_aimContainer;
    UIView *_visualContainer;
    UIView *_filterContainer;
    UIView *_configContainer;

    // Content views
    UIView *_aimContent;
    UIView *_visualContent;
    UIView *_filterContent;
    UIView *_configContent;

    UIView *_innerContent;

    // ── AIM checkmarks ───────────────────────────────────────────────────────
    CAShapeLayer *_aimbotCheckmark;
    CAShapeLayer *_triggerbotCheckmark;
    CAShapeLayer *_fovVisibleCheckmark;
    CAShapeLayer *_visibleCheckCheckmark;
    CAShapeLayer *_shootingCheckCheckmark;
    CAShapeLayer *_aimbotTeamCheckmark;
    CAShapeLayer *_ignoreKnockedAimCheckmark;
    CAShapeLayer *_ignoreBotAimCheckmark;
    CustomSegmentedControl *_boneSelector;
    UILabel *_fovValueLabel;
    UILabel *_smoothValueLabel;
    UILabel *_triggerDelayValueLabel;
    CustomSliderView *_fovSlider;
    CustomSliderView *_smoothSlider;
    CustomSliderView *_triggerDelaySlider;

    // ── VISUAL checkmarks ─────────────────────────────────────────────────────
    CAShapeLayer *_boxCheckmark;
    CAShapeLayer *_boxOutlineCheckmark;
    CAShapeLayer *_boxFillCheckmark;
    CAShapeLayer *_boxCornerCheckmark;
    CAShapeLayer *_boxHpColorCheckmark;
    CAShapeLayer *_lineCheckmark;
    CAShapeLayer *_lineOutlineCheckmark;
    CAShapeLayer *_snaplineCheckmark;
    CAShapeLayer *_teamCheckmark;
    CAShapeLayer *_nameCheckmark;
    CAShapeLayer *_nameOutlineCheckmark;
    CAShapeLayer *_healthCheckmark;
    CAShapeLayer *_healthBarCheckmark;
    CAShapeLayer *_healthBarOutlineCheckmark;
    CAShapeLayer *_distCheckmark;
    CAShapeLayer *_knockedStatusCheckmark;
    CAShapeLayer *_inventoryCheckmark;
    CAShapeLayer *_skillsCheckmark;

    // ── FILTER checkmarks ─────────────────────────────────────────────────────
    CAShapeLayer *_espIgnoreKnockedCheckmark;
    CAShapeLayer *_espIgnoreBotCheckmark;

    // Config
    CGFloat _configListStartY;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;
    self.userInteractionEnabled = YES;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    _blurView.frame = self.bounds;
    _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _blurView.userInteractionEnabled = NO;
    [self addSubview:_blurView];

    CGFloat headerH = 35;
    _headerView = [[UIView alloc] initWithFrame:CGRectMake(0,0,frame.size.width,headerH)];
    _headerView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    _headerView.userInteractionEnabled = YES;
    [self addSubview:_headerView];

    _headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,0,frame.size.width-50,headerH)];
    _headerLabel.text = @(OBF("FF External"));
    _headerLabel.textAlignment = NSTextAlignmentLeft;
    _headerLabel.textColor = [UIColor whiteColor];
    _headerLabel.font = [UIFont boldSystemFontOfSize:14];
    [_headerView addSubview:_headerLabel];

    UIView *arrowContainer = [[UIView alloc] initWithFrame:CGRectMake(frame.size.width-45,0,45,35)];
    arrowContainer.userInteractionEnabled = YES;
    [_headerView addSubview:arrowContainer];
    _arrowLayer = [CAShapeLayer layer];
    _arrowLayer.strokeColor = [UIColor whiteColor].CGColor;
    _arrowLayer.fillColor   = [UIColor clearColor].CGColor;
    _arrowLayer.lineWidth   = 2;
    _arrowLayer.lineCap     = kCALineCapRound;
    _arrowLayer.lineJoin    = kCALineJoinRound;
    UIBezierPath *ap = [UIBezierPath bezierPath];
    [ap moveToPoint:CGPointMake(12,13)]; [ap addLineToPoint:CGPointMake(19,21)]; [ap addLineToPoint:CGPointMake(26,13)];
    _arrowLayer.path  = ap.CGPath;
    _arrowLayer.frame = arrowContainer.bounds;
    [arrowContainer.layer addSublayer:_arrowLayer];
    [arrowContainer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleCollapse)]];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.cancelsTouchesInView = NO;
    [_headerView addGestureRecognizer:pan];

    CGFloat leftW = 70;
    _leftBarView = [[UIView alloc] initWithFrame:CGRectMake(0,headerH,leftW,frame.size.height-headerH)];
    _leftBarView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
    _leftBarView.userInteractionEnabled = YES;
    [self addSubview:_leftBarView];

    // 4 табa: AIM / VISUAL / FILTER / CONFIG
    NSArray *tabs = @[@(OBF("AIM")), @(OBF("VISUAL")), @(OBF("FILTER")), @(OBF("CONFIG"))];
    _tabLabels = [NSMutableArray new];
    for (int i = 0; i < 4; i++) {
        UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(0,i*40,leftW,40)];
        tl.text = tabs[i];
        tl.textAlignment = NSTextAlignmentCenter;
        tl.font      = [UIFont systemFontOfSize:11 weight:(i==0 ? UIFontWeightBold : UIFontWeightRegular)];
        tl.textColor = (i==0 ? [UIColor whiteColor] : [UIColor colorWithWhite:0.7 alpha:1]);
        tl.userInteractionEnabled = YES;
        tl.tag = i;
        [_leftBarView addSubview:tl];
        [_tabLabels addObject:tl];
        [tl addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tabTapped:)]];
    }

    _contentView = [[UIView alloc] initWithFrame:CGRectMake(leftW,headerH,frame.size.width-leftW,frame.size.height-headerH)];
    _contentView.clipsToBounds = YES;
    _contentView.userInteractionEnabled = YES;
    [self addSubview:_contentView];

    _aimContainer    = [[UIView alloc] initWithFrame:_contentView.bounds];
    _visualContainer = [[UIView alloc] initWithFrame:_contentView.bounds];
    _filterContainer = [[UIView alloc] initWithFrame:_contentView.bounds];
    _configContainer = [[UIView alloc] initWithFrame:_contentView.bounds];
    _visualContainer.hidden = YES;
    _filterContainer.hidden = YES;
    _configContainer.hidden = YES;

    _aimContent    = [[UIView alloc] initWithFrame:CGRectMake(0,0,_contentView.bounds.size.width,600)];
    _visualContent = [[UIView alloc] initWithFrame:CGRectMake(0,0,_contentView.bounds.size.width,700)];
    _filterContent = [[UIView alloc] initWithFrame:CGRectMake(0,0,_contentView.bounds.size.width,200)];
    _configContent = [[UIView alloc] initWithFrame:CGRectMake(0,0,_contentView.bounds.size.width,400)];

    [_aimContainer    addSubview:_aimContent];
    [_visualContainer addSubview:_visualContent];
    [_filterContainer addSubview:_filterContent];
    [_configContainer addSubview:_configContent];
    [_contentView addSubview:_aimContainer];
    [_contentView addSubview:_visualContainer];
    [_contentView addSubview:_filterContainer];
    [_contentView addSubview:_configContainer];

    VerticalOnlyPanGestureRecognizer *scrollPan = [[VerticalOnlyPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleScrollPan:)];
    scrollPan.cancelsTouchesInView = YES;
    scrollPan.delegate = self;
    [_contentView addGestureRecognizer:scrollPan];

    CGFloat cw = _contentView.bounds.size.width;
    CGFloat y;

    // ═══════════════════════════════════════════════════════════════════════
    // AIM TAB
    // ═══════════════════════════════════════════════════════════════════════
    _innerContent = _aimContent;
    y = 4;

    [self addSectionHeader:@(OBF("AIMBOT")) atY:y]; y += 26;
    _aimbotCheckmark         = [self addToggle:@(OBF("Aimbot"))        atY:y action:@selector(aimbotTapped)          enabled:aimbot_enabled];        y += 32;
    _triggerbotCheckmark     = [self addToggle:@(OBF("Triggerbot"))    atY:y action:@selector(triggerbotTapped)      enabled:aimbot_triggerbot];      y += 32;
    _fovVisibleCheckmark     = [self addToggle:@(OBF("FOV Circle"))    atY:y action:@selector(fovVisibleTapped)      enabled:aimbot_fov_visible];     y += 32;
    _visibleCheckCheckmark   = [self addToggle:@(OBF("Visible Check")) atY:y action:@selector(visibleCheckTapped)    enabled:aimbot_visible_check];   y += 32;
    _shootingCheckCheckmark  = [self addToggle:@(OBF("Fire Check"))    atY:y action:@selector(shootingCheckTapped)   enabled:aimbot_shooting_check];  y += 32;
    _aimbotTeamCheckmark     = [self addToggle:@(OBF("Team Check"))    atY:y action:@selector(aimbotTeamTapped)      enabled:aimbot_team_check];      y += 32;
    _ignoreKnockedAimCheckmark=[self addToggle:@(OBF("Ignore Knocked"))atY:y action:@selector(ignoreKnockedAimTapped)enabled:aimbot_ignore_knocked];  y += 32;
    _ignoreBotAimCheckmark   = [self addToggle:@(OBF("Ignore Bot"))    atY:y action:@selector(ignoreBotAimTapped)    enabled:aimbot_ignore_bot];      y += 32;

    [self addSectionHeader:@(OBF("Smooth")) atY:y]; y += 26;
    _smoothValueLabel = [self addSliderAtY:y sliderOut:&_smoothSlider min:0 max:20 current:aimbot_smooth
                                    format:@"%.1f" onChange:^(float v){ aimbot_smooth = v; }]; y += 45;

    [self addSectionHeader:@(OBF("FOV")) atY:y]; y += 26;
    _fovValueLabel = [self addSliderAtY:y sliderOut:&_fovSlider min:10 max:300 current:aimbot_fov
                                 format:@"%.0f" onChange:^(float v){ aimbot_fov = v; }]; y += 45;

    [self addSectionHeader:@(OBF("Trigger Delay")) atY:y]; y += 26;
    _triggerDelayValueLabel = [self addSliderAtY:y sliderOut:&_triggerDelaySlider min:0.01 max:1.0
                                         current:aimbot_trigger_delay format:@"%.2f"
                                        onChange:^(float v){ aimbot_trigger_delay = v; }]; y += 45;

    [self addSectionHeader:@(OBF("Bone")) atY:y]; y += 26;
    _boneSelector = [[CustomSegmentedControl alloc] initWithFrame:CGRectMake(10,y,cw-20,28)
                                                            items:@[@"Head",@"Hip"]
                                                          current:aimbot_bone_index];
    _boneSelector.valueChanged = ^(NSInteger idx){ aimbot_bone_index = (int)idx; };
    [_aimContent addSubview:_boneSelector];
    y += 36;
    _aimContent.frame = CGRectMake(0,0,cw,y+10);

    // ═══════════════════════════════════════════════════════════════════════
    // VISUAL TAB
    // ═══════════════════════════════════════════════════════════════════════
    _innerContent = _visualContent;
    y = 4;

    [self addSectionHeader:@(OBF("BOX")) atY:y]; y += 26;
    _boxCheckmark        = [self addToggle:@(OBF("Box 2D"))      atY:y action:@selector(boxTapped)            enabled:esp_box_enabled];        y += 32;
    _boxOutlineCheckmark = [self addToggle:@(OBF("Outline"))     atY:y action:@selector(boxOutlineTapped)     enabled:esp_box_outline];        y += 32;
    _boxFillCheckmark    = [self addToggle:@(OBF("Fill"))        atY:y action:@selector(boxFillTapped)        enabled:esp_box_fill];           y += 32;
    _boxCornerCheckmark  = [self addToggle:@(OBF("Corner"))      atY:y action:@selector(boxCornerTapped)      enabled:esp_box_corner];         y += 32;
    _boxHpColorCheckmark = [self addToggle:@(OBF("HP Color Box"))atY:y action:@selector(boxHpColorTapped)    enabled:esp_box_hp_color];       y += 32;

    [self addSectionHeader:@(OBF("LINES")) atY:y]; y += 26;
    _lineCheckmark        = [self addToggle:@(OBF("Lines"))       atY:y action:@selector(lineTapped)          enabled:esp_line_enabled];       y += 32;
    _lineOutlineCheckmark = [self addToggle:@(OBF("Line Outline"))atY:y action:@selector(lineOutlineTapped)   enabled:esp_line_outline];       y += 32;
    _snaplineCheckmark    = [self addToggle:@(OBF("Snapline"))    atY:y action:@selector(snaplineTapped)      enabled:esp_snapline_enabled];   y += 32;

    [self addSectionHeader:@(OBF("PLAYER INFO")) atY:y]; y += 26;
    _nameCheckmark            = [self addToggle:@(OBF("Name"))         atY:y action:@selector(nameTapped)             enabled:esp_name_enabled];       y += 32;
    _nameOutlineCheckmark     = [self addToggle:@(OBF("Name Outline")) atY:y action:@selector(nameOutlineTapped)      enabled:esp_name_outline];       y += 32;
    _healthCheckmark          = [self addToggle:@(OBF("HP Text"))      atY:y action:@selector(healthTapped)           enabled:esp_health_enabled];     y += 32;
    _healthBarCheckmark       = [self addToggle:@(OBF("HP Bar"))       atY:y action:@selector(healthBarTapped)        enabled:esp_health_bar_enabled]; y += 32;
    _healthBarOutlineCheckmark= [self addToggle:@(OBF("Bar Outline"))  atY:y action:@selector(healthBarOutlineTapped) enabled:esp_health_bar_outline]; y += 32;
    _distCheckmark            = [self addToggle:@(OBF("Distance"))     atY:y action:@selector(distTapped)             enabled:esp_dist_label];         y += 32;
    _knockedStatusCheckmark   = [self addToggle:@(OBF("Knocked Tag"))  atY:y action:@selector(knockedStatusTapped)    enabled:esp_knocked_status];     y += 32;

    [self addSectionHeader:@(OBF("INVENTORY")) atY:y]; y += 26;
    _inventoryCheckmark = [self addToggle:@(OBF("Helmet/Armor/Weapon"))atY:y action:@selector(inventoryTapped) enabled:esp_inventory_enabled]; y += 32;
    _skillsCheckmark    = [self addToggle:@(OBF("Skills + CD"))        atY:y action:@selector(skillsTapped)    enabled:esp_skills_enabled];    y += 32;

    [self addSectionHeader:@(OBF("MISC")) atY:y]; y += 26;
    _teamCheckmark = [self addToggle:@(OBF("Team Check")) atY:y action:@selector(teamTapped) enabled:esp_team_check]; y += 32;

    _visualContent.frame = CGRectMake(0,0,cw,y+10);

    // ═══════════════════════════════════════════════════════════════════════
    // FILTER TAB
    // ═══════════════════════════════════════════════════════════════════════
    _innerContent = _filterContent;
    y = 4;

    [self addSectionHeader:@(OBF("ESP FILTERS")) atY:y]; y += 26;
    _espIgnoreKnockedCheckmark = [self addToggle:@(OBF("Hide Knocked")) atY:y action:@selector(espIgnoreKnockedTapped) enabled:esp_ignore_knocked]; y += 32;
    _espIgnoreBotCheckmark     = [self addToggle:@(OBF("Hide Bots"))    atY:y action:@selector(espIgnoreBotTapped)     enabled:esp_ignore_bot];     y += 32;

    _filterContent.frame = CGRectMake(0,0,cw,y+10);

    // ═══════════════════════════════════════════════════════════════════════
    // CONFIG TAB
    // ═══════════════════════════════════════════════════════════════════════
    _innerContent = _configContent;
    y = 4;
    [self addSectionHeader:@(OBF("CONFIGS")) atY:y]; y += 26;

    CGFloat btnW = (cw - 30) / 3.0;
    NSArray *btnTitles = @[@(OBF("Create")), @(OBF("Delete")), @(OBF("Load"))];
    NSArray *btnSels   = @[NSStringFromSelector(@selector(createConfigFlow)),
                           NSStringFromSelector(@selector(deleteConfigFlow)),
                           NSStringFromSelector(@selector(loadConfigFlow))];
    for (int i = 0; i < 3; i++) {
        UILabel *btn = [[UILabel alloc] initWithFrame:CGRectMake(10+(btnW+5)*i,y,btnW,30)];
        btn.text = btnTitles[i];
        btn.textAlignment = NSTextAlignmentCenter;
        btn.font = [UIFont boldSystemFontOfSize:12];
        btn.textColor = [UIColor blackColor];
        btn.backgroundColor = [UIColor whiteColor];
        btn.layer.cornerRadius = 4; btn.layer.masksToBounds = YES;
        btn.userInteractionEnabled = YES;
        [btn addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:NSSelectorFromString(btnSels[i])]];
        [_configContent addSubview:btn];
    }
    y += 40;
    _configListStartY = y;
    [self refreshConfigList];

    _innerContent = nil;
    [self showViewForCapture];
    return self;
}

// ─── Tab switching ────────────────────────────────────────────────────────────
- (void)tabTapped:(UITapGestureRecognizer *)g {
    NSInteger idx = g.view.tag;
    NSArray *containers = @[_aimContainer, _visualContainer, _filterContainer, _configContainer];
    for (int i = 0; i < 4; i++) {
        UIView *c = containers[i]; c.hidden = (i != idx);
        UILabel *tl = _tabLabels[i];
        tl.font      = [UIFont systemFontOfSize:11 weight:(i==idx ? UIFontWeightBold : UIFontWeightRegular)];
        tl.textColor = (i==idx ? [UIColor whiteColor] : [UIColor colorWithWhite:0.7 alpha:1]);
    }
}

// ─── Collapse ─────────────────────────────────────────────────────────────────
- (void)toggleCollapse {
    _collapsed = !_collapsed;
    [UIView animateWithDuration:0.25 animations:^{
        CGRect f = self.frame;
        f.size.height = self->_collapsed ? 35 : 310;
        self->_leftBarView.hidden  = self->_collapsed;
        self->_contentView.hidden  = self->_collapsed;
        self.frame = f;
    }];
    CABasicAnimation *rot = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rot.toValue = @(_collapsed ? M_PI : 0);
    rot.duration = 0.25; rot.fillMode = kCAFillModeForwards; rot.removedOnCompletion = NO;
    [_arrowLayer addAnimation:rot forKey:@"rotate"];
}

// ─── Scroll ───────────────────────────────────────────────────────────────────
- (void)handleScrollPan:(UIPanGestureRecognizer *)g {
    NSArray *containers = @[_aimContainer, _visualContainer, _filterContainer, _configContainer];
    NSArray *contents   = @[_aimContent,   _visualContent,   _filterContent,   _configContent];
    UIView *activeContent = nil;
    for (int i = 0; i < 4; i++)
        if (!((UIView *)containers[i]).hidden) { activeContent = contents[i]; break; }
    if (!activeContent) return;
    CGFloat dy   = [g translationInView:_contentView].y;
    [g setTranslation:CGPointZero inView:_contentView];
    CGFloat minY = _contentView.bounds.size.height - activeContent.frame.size.height - 8;
    CGFloat newY = fmaxf(minY, fminf(0, activeContent.frame.origin.y + dy));
    CGRect f = activeContent.frame; f.origin.y = newY; activeContent.frame = f;
}

// ─── Drag ─────────────────────────────────────────────────────────────────────
- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint p = [g locationInView:self.superview];
    if (g.state == UIGestureRecognizerStateBegan) { _initialTouchPoint = p; return; }
    self.center = CGPointMake(self.center.x + p.x - _initialTouchPoint.x,
                              self.center.y + p.y - _initialTouchPoint.y);
    _initialTouchPoint = p;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
- (void)addSectionHeader:(NSString *)title atY:(CGFloat)y {
    UILabel *h = [[UILabel alloc] initWithFrame:CGRectMake(12,y,_innerContent.bounds.size.width-24,22)];
    h.text = title; h.textColor = [UIColor colorWithWhite:1 alpha:0.45];
    h.font = [UIFont boldSystemFontOfSize:11]; h.userInteractionEnabled = NO;
    [_innerContent addSubview:h];
}

- (CAShapeLayer *)addToggle:(NSString *)name atY:(CGFloat)y action:(SEL)action enabled:(BOOL)enabled {
    CGFloat w = _innerContent.bounds.size.width;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0,y,w,30)];
    row.userInteractionEnabled = YES;
    [_innerContent addSubview:row];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15,0,w-55,30)];
    lbl.text = name; lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    lbl.userInteractionEnabled = NO;
    [row addSubview:lbl];

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(w-37,4,22,22)];
    box.layer.borderWidth = 2; box.layer.borderColor = [UIColor whiteColor].CGColor;
    box.layer.cornerRadius = 4; box.userInteractionEnabled = NO;
    [row addSubview:box];

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(22*0.20, 22*0.50)];
    [path addLineToPoint:CGPointMake(22*0.42, 22*0.72)];
    [path addLineToPoint:CGPointMake(22*0.80, 22*0.28)];
    CAShapeLayer *cm = [CAShapeLayer layer];
    cm.path = path.CGPath; cm.strokeColor = [UIColor whiteColor].CGColor;
    cm.fillColor = [UIColor clearColor].CGColor; cm.lineWidth = 2.5;
    cm.lineCap = kCALineCapRound; cm.lineJoin = kCALineJoinRound;
    cm.opacity = enabled ? 1.0 : 0.0;
    [box.layer addSublayer:cm];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:action];
    tap.cancelsTouchesInView = NO;
    [row addGestureRecognizer:tap];
    return cm;
}

- (void)animateCheckmark:(CAShapeLayer *)cm show:(BOOL)show {
    if (show) {
        cm.opacity = 1.0;
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        a.fromValue = @0; a.toValue = @1; a.duration = 0.2;
        a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [cm addAnimation:a forKey:@"draw"];
    } else {
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
        a.fromValue = @1; a.toValue = @0; a.duration = 0.15;
        cm.opacity = 0; [cm addAnimation:a forKey:@"hide"];
    }
}

- (UILabel *)addSliderAtY:(CGFloat)y sliderOut:(CustomSliderView *__strong *)sliderOut
                      min:(float)min max:(float)max current:(float)current
                   format:(NSString *)fmt onChange:(void(^)(float))onChange {
    CGFloat w = _innerContent.bounds.size.width;
    UILabel *valLbl = [[UILabel alloc] initWithFrame:CGRectMake(w-60,y-24,50,20)];
    valLbl.textColor = [UIColor whiteColor];
    valLbl.font = [UIFont systemFontOfSize:11];
    valLbl.textAlignment = NSTextAlignmentRight;
    valLbl.text = [NSString stringWithFormat:fmt, current];
    [_innerContent addSubview:valLbl];

    CustomSliderView *sl = [[CustomSliderView alloc] initWithFrame:CGRectMake(15,y,w-30,30)
                                                               min:min max:max current:current];
    __weak UILabel *weakLbl = valLbl;
    sl.valueChanged = ^(float v) { onChange(v); weakLbl.text = [NSString stringWithFormat:fmt, v]; };
    [_innerContent addSubview:sl];
    if (sliderOut) *sliderOut = sl;
    return valLbl;
}

// ─── Toggle actions — AIM ─────────────────────────────────────────────────────
- (void)aimbotTapped          { aimbot_enabled       = !aimbot_enabled;       [self animateCheckmark:_aimbotCheckmark          show:aimbot_enabled];       }
- (void)triggerbotTapped      { aimbot_triggerbot     = !aimbot_triggerbot;    [self animateCheckmark:_triggerbotCheckmark      show:aimbot_triggerbot];     }
- (void)fovVisibleTapped      { aimbot_fov_visible    = !aimbot_fov_visible;   [self animateCheckmark:_fovVisibleCheckmark      show:aimbot_fov_visible];    }
- (void)visibleCheckTapped    { aimbot_visible_check  = !aimbot_visible_check; [self animateCheckmark:_visibleCheckCheckmark    show:aimbot_visible_check];  }
- (void)shootingCheckTapped   { aimbot_shooting_check = !aimbot_shooting_check;[self animateCheckmark:_shootingCheckCheckmark   show:aimbot_shooting_check]; }
- (void)aimbotTeamTapped      { aimbot_team_check     = !aimbot_team_check;    [self animateCheckmark:_aimbotTeamCheckmark      show:aimbot_team_check];     }
- (void)ignoreKnockedAimTapped{ aimbot_ignore_knocked = !aimbot_ignore_knocked;[self animateCheckmark:_ignoreKnockedAimCheckmark show:aimbot_ignore_knocked];}
- (void)ignoreBotAimTapped    { aimbot_ignore_bot     = !aimbot_ignore_bot;    [self animateCheckmark:_ignoreBotAimCheckmark    show:aimbot_ignore_bot];     }

// ─── Toggle actions — VISUAL ──────────────────────────────────────────────────
- (void)boxTapped             { esp_box_enabled        = !esp_box_enabled;        [self animateCheckmark:_boxCheckmark             show:esp_box_enabled];        }
- (void)boxOutlineTapped      { esp_box_outline        = !esp_box_outline;        [self animateCheckmark:_boxOutlineCheckmark      show:esp_box_outline];        }
- (void)boxFillTapped         { esp_box_fill           = !esp_box_fill;           [self animateCheckmark:_boxFillCheckmark         show:esp_box_fill];           }
- (void)boxCornerTapped       { esp_box_corner         = !esp_box_corner;         [self animateCheckmark:_boxCornerCheckmark       show:esp_box_corner];         }
- (void)boxHpColorTapped      { esp_box_hp_color       = !esp_box_hp_color;       [self animateCheckmark:_boxHpColorCheckmark      show:esp_box_hp_color];       }
- (void)lineTapped            { esp_line_enabled       = !esp_line_enabled;       [self animateCheckmark:_lineCheckmark            show:esp_line_enabled];       }
- (void)lineOutlineTapped     { esp_line_outline       = !esp_line_outline;       [self animateCheckmark:_lineOutlineCheckmark     show:esp_line_outline];       }
- (void)snaplineTapped        { esp_snapline_enabled   = !esp_snapline_enabled;   [self animateCheckmark:_snaplineCheckmark        show:esp_snapline_enabled];   }
- (void)teamTapped            { esp_team_check         = !esp_team_check;         [self animateCheckmark:_teamCheckmark            show:esp_team_check];         }
- (void)nameTapped            { esp_name_enabled       = !esp_name_enabled;       [self animateCheckmark:_nameCheckmark            show:esp_name_enabled];       }
- (void)nameOutlineTapped     { esp_name_outline       = !esp_name_outline;       [self animateCheckmark:_nameOutlineCheckmark     show:esp_name_outline];       }
- (void)healthTapped          { esp_health_enabled     = !esp_health_enabled;     [self animateCheckmark:_healthCheckmark          show:esp_health_enabled];     }
- (void)healthBarTapped       { esp_health_bar_enabled = !esp_health_bar_enabled; [self animateCheckmark:_healthBarCheckmark       show:esp_health_bar_enabled]; }
- (void)healthBarOutlineTapped{ esp_health_bar_outline = !esp_health_bar_outline; [self animateCheckmark:_healthBarOutlineCheckmark show:esp_health_bar_outline];}
- (void)distTapped            { esp_dist_label         = !esp_dist_label;         [self animateCheckmark:_distCheckmark            show:esp_dist_label];         }
- (void)knockedStatusTapped   { esp_knocked_status     = !esp_knocked_status;     [self animateCheckmark:_knockedStatusCheckmark   show:esp_knocked_status];     }
- (void)inventoryTapped       { esp_inventory_enabled  = !esp_inventory_enabled;  [self animateCheckmark:_inventoryCheckmark       show:esp_inventory_enabled];  }
- (void)skillsTapped          { esp_skills_enabled     = !esp_skills_enabled;     [self animateCheckmark:_skillsCheckmark          show:esp_skills_enabled];     }

// ─── Toggle actions — FILTER ──────────────────────────────────────────────────
- (void)espIgnoreKnockedTapped{ esp_ignore_knocked = !esp_ignore_knocked; [self animateCheckmark:_espIgnoreKnockedCheckmark show:esp_ignore_knocked]; }
- (void)espIgnoreBotTapped    { esp_ignore_bot     = !esp_ignore_bot;     [self animateCheckmark:_espIgnoreBotCheckmark     show:esp_ignore_bot];     }

// ─── Config ───────────────────────────────────────────────────────────────────
- (void)refreshConfigList {
    for (UIView *v in [_configContent subviews])
        if (v.tag == 999) [v removeFromSuperview];
    NSArray *configs = cfg_get_list();
    CGFloat y = _configListStartY;
    CGFloat w = _configContent.bounds.size.width;
    for (NSString *name in configs) {
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(15,y,w-30,28)];
        l.text = [NSString stringWithFormat:@"  %@", name];
        BOOL sel = [esp_selected_config isEqualToString:name];
        l.textColor = sel ? [UIColor whiteColor] : [UIColor colorWithWhite:0.7 alpha:1];
        l.font = [UIFont systemFontOfSize:13];
        l.backgroundColor = sel ? [UIColor colorWithWhite:1 alpha:0.15] : [UIColor clearColor];
        l.layer.cornerRadius = 4; l.layer.masksToBounds = YES;
        l.userInteractionEnabled = YES; l.tag = 999;
        [l addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectConfig:)]];
        objc_setAssociatedObject(l, "cfgName", name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [_configContent addSubview:l];
        y += 32;
    }
    CGRect f = _configContent.frame; f.size.height = y+10; _configContent.frame = f;
}

- (void)selectConfig:(UITapGestureRecognizer *)g {
    esp_selected_config = objc_getAssociatedObject(g.view, "cfgName");
    [self refreshConfigList];
}

- (void)createConfigFlow {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New Config" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *f){ f.placeholder = @"Config name"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *name = alert.textFields.firstObject.text;
        if (name.length > 0) { cfg_create(name); [self refreshConfigList]; }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)deleteConfigFlow {
    if (!esp_selected_config) return;
    cfg_delete(esp_selected_config); esp_selected_config = nil; [self refreshConfigList];
}

- (void)loadConfigFlow {
    if (!esp_selected_config) return;
    cfg_load(esp_selected_config);
    // Refresh все чекмарки
    [self animateCheckmark:_aimbotCheckmark           show:aimbot_enabled];
    [self animateCheckmark:_triggerbotCheckmark       show:aimbot_triggerbot];
    [self animateCheckmark:_fovVisibleCheckmark       show:aimbot_fov_visible];
    [self animateCheckmark:_boxCheckmark              show:esp_box_enabled];
    [self animateCheckmark:_boxHpColorCheckmark       show:esp_box_hp_color];
    [self animateCheckmark:_snaplineCheckmark         show:esp_snapline_enabled];
    [self animateCheckmark:_nameCheckmark             show:esp_name_enabled];
    [self animateCheckmark:_healthCheckmark           show:esp_health_enabled];
    [self animateCheckmark:_healthBarCheckmark        show:esp_health_bar_enabled];
    [self animateCheckmark:_distCheckmark             show:esp_dist_label];
    [self animateCheckmark:_knockedStatusCheckmark    show:esp_knocked_status];
    [self animateCheckmark:_inventoryCheckmark        show:esp_inventory_enabled];
    [self animateCheckmark:_skillsCheckmark           show:esp_skills_enabled];
    [self animateCheckmark:_espIgnoreKnockedCheckmark show:esp_ignore_knocked];
    [self animateCheckmark:_espIgnoreBotCheckmark     show:esp_ignore_bot];
    [_boneSelector reloadUI:aimbot_bone_index];
    _fovValueLabel.text    = [NSString stringWithFormat:@"%.0f", aimbot_fov];
    _smoothValueLabel.text = [NSString stringWithFormat:@"%.1f", aimbot_smooth];
    [_fovSlider setValue:aimbot_fov];
    [_smoothSlider setValue:aimbot_smooth];
}

- (void)didMoveToSuperview { [super didMoveToSuperview]; [self centerMenu]; }
- (void)centerMenu {
    if (self.superview)
        self.center = CGPointMake(self.superview.bounds.size.width/2, self.superview.bounds.size.height/2);
}
- (void)dealloc {}

@end

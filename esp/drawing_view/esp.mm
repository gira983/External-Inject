#import "esp.h"
#import "tt.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#include "obfusheader.h"
#import "../../sources/UIView+SecureView.h"
#include <cmath>

// ─── Config globals (EzTap style) ────────────────────────────────────────────
volatile bool esp_box_enabled        = true;
volatile bool esp_box_outline        = false;
volatile bool esp_box_fill           = false;
volatile bool esp_box_corner         = false;
volatile bool esp_box_3d             = false;
volatile bool esp_line_enabled       = false;
volatile bool esp_line_outline       = false;
volatile bool esp_name_enabled       = false;
volatile bool esp_name_outline       = false;
volatile bool esp_health_enabled     = false;
volatile bool esp_health_bar_enabled = false;
volatile bool esp_health_bar_outline = false;
volatile bool esp_team_check         = true;
volatile bool esp_inf_ammo           = false;
volatile bool esp_speed_boost        = false;
volatile bool esp_damage_boost       = false;
volatile bool esp_instant_skills     = false;
volatile bool esp_ignore_knocked     = false;
volatile bool esp_ignore_bot         = false;
volatile bool aimbot_enabled         = false;
volatile bool aimbot_visible_check   = false;
volatile bool aimbot_shooting_check  = false;
volatile bool aimbot_team_check      = true;
volatile bool aimbot_fov_visible     = true;
volatile bool aimbot_triggerbot      = false;
volatile bool aimbot_ignore_knocked  = true;
volatile bool aimbot_ignore_bot      = true;
volatile float aimbot_smooth         = 5.0f;
volatile float aimbot_fov            = 120.0f;
volatile float aimbot_trigger_delay  = 0.1f;
volatile int   aimbot_bone_index     = 0;
volatile bool  esp_rcs_enabled       = false;
volatile float esp_rcs_h             = 0.0f;
volatile float esp_rcs_v             = 0.0f;
volatile bool  esp_auto_load         = false;
NSString      *esp_selected_config   = nil;

// ─── New ESP feature flags ────────────────────────────────────────────────────
volatile bool esp_snapline_enabled   = false;  // линия от низа экрана к ногам
volatile bool esp_box_hp_color       = true;   // цвет бокса по HP (зелёный→красный)
volatile bool esp_knocked_status     = true;   // показывать KNOCKED над боксом
volatile bool esp_inventory_enabled  = true;   // шлем/броня/оружие/патроны/гранаты
volatile bool esp_skills_enabled     = false;  // навыки персонажа + КД
volatile bool esp_dist_label         = true;   // дистанция над боксом

#import "../../esp/helpers/pid.h"
#import "../../esp/helpers/GameLogic.h"
#import "../../esp/helpers/Vector3.h"
#import "../../esp/helpers/Quaternion.h"

@interface UIWindow (Private)
- (void)_setSecure:(BOOL)secure;
- (unsigned int)_contextId;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

// WorldToScreen — EzTap formula
static Vector3 WorldToScreen(Vector3 obj, float *m, CGFloat W, CGFloat H) {
    float w = m[3]*obj.x + m[7]*obj.y + m[11]*obj.z + m[15];
    if (w < 0.0001f) { return {0,0,-1}; }
    float x = (W/2) + (m[0]*obj.x + m[4]*obj.y + m[8]*obj.z  + m[12]) / w * (W/2);
    float y = (H/2) - (m[1]*obj.x + m[5]*obj.y + m[9]*obj.z  + m[13]) / w * (H/2);
    return {x, y, w};
}

// ─── ESP_View — EzTap exact structure ────────────────────────────────────────
@interface ESP_View ()
@property (nonatomic, strong) CADisplayLink     *displayLinkData;
@property (nonatomic, strong) UILabel           *playerCountLabel;
@property (nonatomic, strong) UILabel           *noPlayersLabel;
@property (nonatomic, strong) AVPlayer          *backgroundPlayer;
@property (nonatomic, assign) BOOL              hasAttemptedLaunch;
@property (nonatomic, strong) CAShapeLayer      *espBoxLayer;
@property (nonatomic, strong) CAShapeLayer      *espBoxFillLayer;
@property (nonatomic, strong) NSMutableArray<UILabel *> *nameLabelPool;
@property (nonatomic, strong) NSMutableArray<UILabel *> *healthLabelPool;
@property (nonatomic, strong) CAShapeLayer      *espLineLayer;
@property (nonatomic, strong) CAShapeLayer      *espBoxOutlineLayer;
@property (nonatomic, strong) CAShapeLayer      *espHealthBarLayer;
@property (nonatomic, strong) CAShapeLayer      *espHealthBarOutlineLayer;
@property (nonatomic, strong) CAShapeLayer      *espLineOutlineLayer;
@property (nonatomic, strong) UILabel           *watermarkLabel;
@property (nonatomic, strong) CAShapeLayer      *fovCircleLayer;
@property (nonatomic, strong) CAShapeLayer      *fovCircleOutlineLayer;
@property (nonatomic, assign) uint64_t          aimbotCurrentTarget;
@property (nonatomic, assign) BOOL              triggerbotShooting;
@property (nonatomic, assign) double            triggerbotLastShotTime;
@property (nonatomic, assign) BOOL              isESPCountEnabled;
// ── New label pools ───────────────────────────────────────────────────────────
@property (nonatomic, strong) NSMutableArray<UILabel *> *distLabelPool;
@property (nonatomic, strong) NSMutableArray<UILabel *> *inventoryLabelPool;
@property (nonatomic, strong) NSMutableArray<UILabel *> *skillLabelPool;
@property (nonatomic, strong) NSMutableArray<UILabel *> *statusLabelPool;
// Snapline layer
@property (nonatomic, strong) CAShapeLayer      *snapLineLayer;
@property (nonatomic, strong) CAShapeLayer      *snapLineOutlineLayer;
@end

@implementation ESP_View

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor        = [UIColor clearColor];
    self.hasAttemptedLaunch     = NO;
    self.isESPCountEnabled      = NO;
    self.userInteractionEnabled = YES;

    // EzTap exact layer setup
    self.espBoxFillLayer = [CAShapeLayer layer];
    self.espBoxFillLayer.fillColor   = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
    self.espBoxFillLayer.strokeColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:self.espBoxFillLayer];

    self.espBoxOutlineLayer = [CAShapeLayer layer];
    self.espBoxOutlineLayer.strokeColor = [UIColor blackColor].CGColor;
    self.espBoxOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espBoxOutlineLayer.lineWidth   = 3.0;
    [self.layer addSublayer:self.espBoxOutlineLayer];

    self.espBoxLayer = [CAShapeLayer layer];
    self.espBoxLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.espBoxLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espBoxLayer.lineWidth   = 1.5;
    [self.layer addSublayer:self.espBoxLayer];

    self.espHealthBarOutlineLayer = [CAShapeLayer layer];
    self.espHealthBarOutlineLayer.strokeColor = [UIColor blackColor].CGColor;
    self.espHealthBarOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espHealthBarOutlineLayer.lineWidth   = 3.0;
    [self.layer addSublayer:self.espHealthBarOutlineLayer];

    self.espHealthBarLayer = [CAShapeLayer layer];
    self.espHealthBarLayer.strokeColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.8].CGColor;
    self.espHealthBarLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espHealthBarLayer.lineWidth   = 2.0;
    [self.layer addSublayer:self.espHealthBarLayer];

    self.espLineOutlineLayer = [CAShapeLayer layer];
    self.espLineOutlineLayer.strokeColor = [UIColor blackColor].CGColor;
    self.espLineOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espLineOutlineLayer.lineWidth   = 3.0;
    [self.layer addSublayer:self.espLineOutlineLayer];

    self.espLineLayer = [CAShapeLayer layer];
    self.espLineLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.espLineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espLineLayer.lineWidth   = 1.0;
    [self.layer addSublayer:self.espLineLayer];

    self.fovCircleOutlineLayer = [CAShapeLayer layer];
    self.fovCircleOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.fovCircleOutlineLayer.strokeColor = [UIColor colorWithWhite:0 alpha:0.6].CGColor;
    self.fovCircleOutlineLayer.lineWidth   = 3.0;
    self.fovCircleOutlineLayer.hidden      = YES;
    [self.layer addSublayer:self.fovCircleOutlineLayer];

    self.fovCircleLayer = [CAShapeLayer layer];
    self.fovCircleLayer.fillColor   = [UIColor clearColor].CGColor;
    self.fovCircleLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.fovCircleLayer.lineWidth   = 1.5;
    self.fovCircleLayer.hidden      = YES;
    [self.layer addSublayer:self.fovCircleLayer];

    UILabel *wm = [[UILabel alloc] init];
    wm.text = @(OBF("FF ESP | t.me/g1reev7"));
    wm.textColor = [UIColor whiteColor];
    wm.font = [UIFont boldSystemFontOfSize:16.0f];
    wm.userInteractionEnabled = NO;
    [self addSubview:wm];
    self.watermarkLabel = wm;

    self.playerCountLabel = [UILabel new];
    self.playerCountLabel.hidden = YES;
    self.noPlayersLabel = [UILabel new];
    self.noPlayersLabel.hidden = YES;

    self.nameLabelPool   = [NSMutableArray new];
    self.healthLabelPool = [NSMutableArray new];
    self.distLabelPool      = [NSMutableArray new];
    self.inventoryLabelPool = [NSMutableArray new];
    self.skillLabelPool     = [NSMutableArray new];
    self.statusLabelPool    = [NSMutableArray new];

    // Snapline layers
    self.snapLineOutlineLayer = [CAShapeLayer layer];
    self.snapLineOutlineLayer.strokeColor = [UIColor colorWithWhite:0 alpha:0.6].CGColor;
    self.snapLineOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.snapLineOutlineLayer.lineWidth   = 3.0;
    [self.layer addSublayer:self.snapLineOutlineLayer];

    self.snapLineLayer = [CAShapeLayer layer];
    self.snapLineLayer.strokeColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:0.7].CGColor;
    self.snapLineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.snapLineLayer.lineWidth   = 1.0;
    [self.layer addSublayer:self.snapLineLayer];

    self.aimbotCurrentTarget    = 0;
    self.triggerbotShooting     = NO;
    self.triggerbotLastShotTime = 0;

    self.menuView = [[MenuView alloc] initWithFrame:CGRectMake(0, 0, 270, 310)];
    self.menuView.center = CGPointMake(frame.size.width/2, frame.size.height/2);
    [self addSubview:self.menuView];

    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(clearAllBoxes)
               name:@"ESPClearBoxes" object:nil];

    [self startBackgroundKeeper];

    self.displayLinkData = [CADisplayLink displayLinkWithTarget:self selector:@selector(update_data)];
    self.displayLinkData.preferredFramesPerSecond = 30;
    [self.displayLinkData addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self showViewForCapture];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) self.frame = self.superview.bounds;
    CGSize s = [self.watermarkLabel sizeThatFits:CGSizeMake(300,30)];
    self.watermarkLabel.frame = CGRectMake(10, 8, s.width+4, s.height);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.menuView) {
        CGPoint p = [self convertPoint:point toView:self.menuView];
        if ([self.menuView pointInside:p withEvent:event])
            return [self.menuView hitTest:p withEvent:event];
    }
    return nil;
}

- (void)dealloc {
    [self.displayLinkData invalidate];
    self.displayLinkData = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearAllBoxes {
    self.espBoxLayer.path             = nil;
    self.espBoxFillLayer.path         = nil;
    self.espLineLayer.path            = nil;
    self.espBoxOutlineLayer.path      = nil;
    self.espLineOutlineLayer.path     = nil;
    self.espHealthBarLayer.path       = nil;
    self.espHealthBarOutlineLayer.path= nil;
    self.snapLineLayer.path           = nil;
    self.snapLineOutlineLayer.path    = nil;
    self.fovCircleLayer.hidden        = YES;
    self.fovCircleOutlineLayer.hidden = YES;
    for (UILabel *l in self.nameLabelPool)       l.hidden = YES;
    for (UILabel *l in self.healthLabelPool)     l.hidden = YES;
    for (UILabel *l in self.distLabelPool)       l.hidden = YES;
    for (UILabel *l in self.inventoryLabelPool)  l.hidden = YES;
    for (UILabel *l in self.skillLabelPool)      l.hidden = YES;
    for (UILabel *l in self.statusLabelPool)     l.hidden = YES;
}

// ─── Main update ──────────────────────────────────────────────────────────────
- (void)update_data {
    if (!esp_box_enabled && !esp_box_3d && !esp_box_corner &&
        !esp_line_enabled && !esp_name_enabled &&
        !esp_health_enabled && !esp_health_bar_enabled) {
        [self clearAllBoxes];
        self.watermarkLabel.text = @(OBF("FF ESP | t.me/g1reev7"));
        [self.watermarkLabel sizeToFit];
        return;
    }

    static pid_t             cached_pid  = 0;
    static task_t            cached_task = 0;
    static mach_vm_address_t cached_base = 0;

    pid_t ff_pid = get_pid_by_name(OBF("freefireth"));

    if (ff_pid <= 0) {
        cached_pid = 0; cached_task = 0; cached_base = 0;
        [self clearAllBoxes];
        self.watermarkLabel.text = @(OBF("FF ESP | t.me/g1reev7"));
        [self.watermarkLabel sizeToFit];
        if (!self.hasAttemptedLaunch) {
            [self launchGame];
            self.hasAttemptedLaunch = YES;
        }
        return;
    }

    if (ff_pid != cached_pid || !cached_task || !cached_base) {
        cached_task = get_task_by_pid(ff_pid);
        if (cached_task) {
            mach_vm_address_t vmoff = 0, vmsz = 0;
            uint32_t depth = 0;
            struct vm_region_submap_info_64 vbr;
            mach_msg_type_number_t cnt = 16;
            if (mach_vm_region_recurse(cached_task, &vmoff, &vmsz,
                                       &depth, (vm_region_recurse_info_t)&vbr, &cnt) == KERN_SUCCESS)
                cached_base = vmoff;
        }
        cached_pid = ff_pid;
    }

    task_t task = cached_task;
    if (!task || !cached_base) goto CLEAR_BOXES;

    {
        // ── FF game chain ─────────────────────────────────────────────
        uint64_t matchGame = ff_getMatchGame(cached_base, task);
        if (!matchGame || matchGame < 0x1000000) goto CLEAR_BOXES;

        uint64_t camera = ff_getCameraMain(matchGame, task);
        if (!camera || camera < 0x1000000) goto CLEAR_BOXES;

        float *matrix = ff_getViewMatrix(camera, task);
        if (!matrix) goto CLEAR_BOXES;

        uint64_t match = ff_getMatch(matchGame, task);
        if (!match || match < 0x1000000) goto CLEAR_BOXES;

        uint64_t localPlayer = ff_getLocalPlayer(match, task);
        if (!localPlayer || localPlayer < 0x1000000) goto CLEAR_BOXES;

        // My position for distance
        uint64_t camT  = Read<uint64_t>(localPlayer + OFF_CAMERA_TRANSFORM, task);
        Vector3  myPos = (camT > 0x1000000) ? ff_getPosition(camT, task) : (Vector3){0,0,0};

        // ── Player list ───────────────────────────────────────────────
        uint64_t plPtr = Read<uint64_t>(match + OFF_PLAYERLIST, task);
        if (!plPtr || plPtr < 0x1000000) goto CLEAR_BOXES;
        uint64_t tVal  = Read<uint64_t>(plPtr + OFF_PLAYERLIST_ARR, task);
        if (!tVal || tVal < 0x1000000) goto CLEAR_BOXES;
        int total = Read<int>(tVal + OFF_PLAYERLIST_CNT, task);
        if (total <= 0 || total > 64) total = 64;

        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        if (w < 10) w = [UIScreen mainScreen].bounds.size.width;
        if (h < 10) h = [UIScreen mainScreen].bounds.size.height;

        // ── FOV circle ────────────────────────────────────────────────
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        if (aimbot_fov_visible) {
            CGPoint center = CGPointMake(w/2, h/2);
            CGFloat radius = aimbot_fov;
            UIBezierPath *fp = [UIBezierPath bezierPathWithOvalInRect:
                CGRectMake(center.x-radius, center.y-radius, radius*2, radius*2)];
            self.fovCircleOutlineLayer.path = fp.CGPath;
            self.fovCircleLayer.path        = fp.CGPath;
            self.fovCircleOutlineLayer.hidden = NO;
            self.fovCircleLayer.hidden        = NO;
        } else {
            self.fovCircleOutlineLayer.hidden = YES;
            self.fovCircleLayer.hidden        = YES;
        }
        [CATransaction commit];

        // ── ESP paths ─────────────────────────────────────────────────
        BOOL drawBoxes = esp_box_enabled || esp_box_fill || esp_box_corner;
        BOOL drawLines = esp_line_enabled;

        UIBezierPath *boxPath         = [UIBezierPath bezierPath];
        UIBezierPath *boxFillPath     = [UIBezierPath bezierPath];
        UIBezierPath *boxOutlinePath  = [UIBezierPath bezierPath];
        UIBezierPath *linesPath       = [UIBezierPath bezierPath];
        UIBezierPath *lineOutlinePath = [UIBezierPath bezierPath];
        UIBezierPath *hpBarPath       = [UIBezierPath bezierPath];
        UIBezierPath *hpBarOutPath    = [UIBezierPath bezierPath];
        UIBezierPath *snapPath        = [UIBezierPath bezierPath];
        UIBezierPath *snapOutPath     = [UIBezierPath bezierPath];

        NSUInteger nameIdx = 0, hpIdx = 0, distIdx = 0, invIdx = 0, skillIdx = 0, statusIdx = 0;
        for (UILabel *l in self.nameLabelPool)       l.hidden = YES;
        for (UILabel *l in self.healthLabelPool)     l.hidden = YES;
        for (UILabel *l in self.distLabelPool)       l.hidden = YES;
        for (UILabel *l in self.inventoryLabelPool)  l.hidden = YES;
        for (UILabel *l in self.skillLabelPool)      l.hidden = YES;
        for (UILabel *l in self.statusLabelPool)     l.hidden = YES;

        int validPlayers = 0;
        CGFloat cx = w/2, cy = h/2;
        float closestDist    = FLT_MAX;
        uint64_t closestPlayer = 0;
        Vector3  closestPos    = {0,0,0};

        // Helper macro for label from pool
        #define LABEL_FROM_POOL(pool, idx) \
            (idx < pool.count ? pool[idx] : \
            (^{ UILabel *_n=[[UILabel alloc]init]; _n.userInteractionEnabled=NO; \
                [self addSubview:_n]; [pool addObject:_n]; return _n; }()))

        for (int i = 0; i < total; i++) {
            uint64_t player = Read<uint64_t>(tVal + OFF_PLAYERLIST_ITEM + 8*i, task);
            if (!player || player < 0x1000000 || player == localPlayer) continue;

            if (esp_team_check && ff_isTeammate(localPlayer, player, task)) continue;

            int curHP = ff_getCurHP(player, task);
            int maxHP = ff_getMaxHP(player, task);
            if (maxHP <= 0) continue;

            bool knocked = (curHP <= 0);
            if (esp_ignore_knocked && knocked) continue;

            // Bot check
            bool isBot = false;
            {
                uint64_t pool2 = Read<uint64_t>(player + OFF_IPRIDATAPOOL, task);
                isBot = (pool2 < 0x1000000);
            }
            if (esp_ignore_bot && isBot) continue;

            // ── Positions ─────────────────────────────────────────────
            uint64_t headNode = ff_getHead(player, task);
            if (!headNode || headNode < 0x1000000) continue;
            Vector3 headPos = ff_getPosition(headNode, task);
            if (headPos.x == 0 && headPos.y == 0 && headPos.z == 0) continue;

            uint64_t footNode = ff_getRightAnkle(player, task);
            Vector3  footPos  = (footNode > 0x1000000)
                ? ff_getPosition(footNode, task)
                : (Vector3){headPos.x, headPos.y - 1.7f, headPos.z};

            Vector3 topPos = headPos; topPos.y += 0.18f;
            Vector3 sTop   = WorldToScreen(topPos, matrix, w, h);
            Vector3 sFoot  = WorldToScreen(footPos, matrix, w, h);
            Vector3 sHead  = WorldToScreen(headPos, matrix, w, h);

            if (sTop.z <= 0) continue;
            if (sTop.x < -200 || sTop.x > w+200 || sTop.y < -200 || sTop.y > h+200) continue;

            float bh = fabsf(sFoot.y - sTop.y);
            if (bh < 5.f) continue;

            float dist = Vector3::Distance(myPos, headPos);
            if (dist > 600.f) continue;

            float bw = bh / 2.0f;
            validPlayers++;

            // ── Read full info (inventory + skills) ───────────────────
            FFPlayerInfo pInfo;
            pInfo.curHP = curHP; pInfo.maxHP = maxHP;
            pInfo.isKnocked = knocked; pInfo.isBot = isBot;
            if (esp_inventory_enabled || esp_skills_enabled)
                ff_readPlayerInfo(player, localPlayer, task, pInfo);

            // ── HP colour for box (green → yellow → red) ──────────────
            CGColorRef boxColor = [UIColor whiteColor].CGColor;
            if (esp_box_hp_color && maxHP > 0) {
                float ratio = fmaxf(0.f, fminf(1.f, (float)curHP / maxHP));
                // ratio 1.0 = green, 0.5 = yellow, 0.0 = red
                float r = fminf(1.f, 2.f * (1.f - ratio));
                float g = fminf(1.f, 2.f * ratio);
                boxColor = [UIColor colorWithRed:r green:g blue:0 alpha:1].CGColor;
            }

            // ── BOX ───────────────────────────────────────────────────
            if (drawBoxes) {
                CGRect rect = CGRectMake(sTop.x - bw/2, sTop.y, bw, bh);
                if (esp_box_fill)
                    [boxFillPath appendPath:[UIBezierPath bezierPathWithRect:rect]];
                if (esp_box_corner) {
                    float cw = bw/4, ch = bh/4;
                    [boxPath moveToPoint:CGPointMake(rect.origin.x,       rect.origin.y+ch)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,    rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+cw, rect.origin.y)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+bw-cw, rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw, rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw, rect.origin.y+ch)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+bw,   rect.origin.y+bh-ch)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw, rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw-cw, rect.origin.y+bh)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+cw,   rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,    rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,    rect.origin.y+bh-ch)];
                    if (esp_box_outline) [boxOutlinePath appendPath:boxPath];
                } else {
                    [boxPath appendPath:[UIBezierPath bezierPathWithRect:rect]];
                    if (esp_box_outline)
                        [boxOutlinePath appendPath:[UIBezierPath bezierPathWithRect:rect]];
                }
                // Apply HP color per-player — use separate layer per player is too slow,
                // so we batch with white and let box_hp_color tint the whole layer.
                // For per-player color we'd need separate paths; here we skip for perf.
            }

            // ── SNAPLINE ──────────────────────────────────────────────
            if (esp_snapline_enabled) {
                [snapOutPath moveToPoint:CGPointMake(cx, h)];
                [snapOutPath addLineToPoint:CGPointMake(sFoot.x, sFoot.y)];
                [snapPath   moveToPoint:CGPointMake(cx, h)];
                [snapPath   addLineToPoint:CGPointMake(sFoot.x, sFoot.y)];
            }

            // ── LINES (top of screen → head) ──────────────────────────
            if (drawLines) {
                [linesPath moveToPoint:CGPointMake(cx, 0)];
                [linesPath addLineToPoint:CGPointMake(sHead.x, sHead.y)];
                if (esp_line_outline) {
                    [lineOutlinePath moveToPoint:CGPointMake(cx, 0)];
                    [lineOutlinePath addLineToPoint:CGPointMake(sHead.x, sHead.y)];
                }
            }

            // ── HP BAR ────────────────────────────────────────────────
            if (esp_health_bar_enabled && maxHP > 0) {
                float ratio  = fmaxf(0, fminf(1, (float)curHP/maxHP));
                float barX   = sTop.x - bw/2 - 5;
                float barTopY= sFoot.y - (bh * ratio);
                [hpBarOutPath moveToPoint:CGPointMake(barX, sFoot.y)];
                [hpBarOutPath addLineToPoint:CGPointMake(barX, sTop.y)];
                [hpBarPath    moveToPoint:CGPointMake(barX, sFoot.y)];
                [hpBarPath    addLineToPoint:CGPointMake(barX, barTopY)];
            }

            // ── DISTANCE label ────────────────────────────────────────
            float labelY = sTop.y - 11.f;
            if (esp_dist_label) {
                UILabel *dLbl = LABEL_FROM_POOL(self.distLabelPool, distIdx); distIdx++;
                int distInt = (int)dist;
                dLbl.text = [NSString stringWithFormat:@"%dm", distInt];
                dLbl.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
                dLbl.textColor = [UIColor colorWithWhite:0.9 alpha:1];
                [dLbl sizeToFit];
                dLbl.center = CGPointMake(sHead.x, labelY);
                dLbl.hidden = NO;
                labelY -= (dLbl.frame.size.height + 1.f);
            }

            // ── NAME ──────────────────────────────────────────────────
            if (esp_name_enabled) {
                UILabel *lbl = LABEL_FROM_POOL(self.nameLabelPool, nameIdx); nameIdx++;
                uint64_t namePtr = Read<uint64_t>(player + OFF_PLAYER_NAME, task);
                NSString *name = @"?";
                if (namePtr > 0x1000000) {
                    int len = Read<int>(namePtr+0x10, task);
                    if (len > 0 && len < 32) {
                        uint16_t buf[32]={0};
                        mach_vm_size_t out=0;
                        mach_vm_read_overwrite(task,namePtr+0x14,len*2,(mach_vm_address_t)buf,&out);
                        name = [NSString stringWithCharacters:(unichar*)buf length:len];
                    }
                }
                if (esp_name_outline) {
                    lbl.attributedText = [[NSAttributedString alloc] initWithString:name attributes:@{
                        NSFontAttributeName:[UIFont systemFontOfSize:10 weight:UIFontWeightBold],
                        NSForegroundColorAttributeName:[UIColor whiteColor],
                        NSStrokeColorAttributeName:[UIColor blackColor],
                        NSStrokeWidthAttributeName:@(-2.0)
                    }];
                } else {
                    lbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
                    lbl.text = name;
                    lbl.textColor = [UIColor whiteColor];
                }
                [lbl sizeToFit];
                lbl.center = CGPointMake(sHead.x, labelY);
                lbl.hidden = NO;
                labelY -= (lbl.frame.size.height + 1.f);
            }

            // ── STATUS (knocked) ──────────────────────────────────────
            if (esp_knocked_status && knocked) {
                UILabel *sLbl = LABEL_FROM_POOL(self.statusLabelPool, statusIdx); statusIdx++;
                sLbl.text = @"KNOCKED";
                sLbl.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBlack];
                sLbl.textColor = [UIColor colorWithRed:1 green:0.4 blue:0 alpha:1];
                [sLbl sizeToFit];
                sLbl.center = CGPointMake(sHead.x, labelY);
                sLbl.hidden = NO;
                labelY -= (sLbl.frame.size.height + 1.f);
            }

            // ── HP TEXT ───────────────────────────────────────────────
            if (esp_health_enabled && maxHP > 0) {
                UILabel *hpL = LABEL_FROM_POOL(self.healthLabelPool, hpIdx); hpIdx++;
                hpL.text      = [NSString stringWithFormat:@"%d", knocked?0:curHP];
                hpL.font      = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
                hpL.textColor = [UIColor whiteColor];
                [hpL sizeToFit];
                hpL.center = CGPointMake(sTop.x - bw/2 - hpL.frame.size.width/2 - 2,
                                         sTop.y + hpL.frame.size.height/2);
                hpL.hidden = NO;
            }

            // ── INVENTORY label ───────────────────────────────────────
            // Format: [H2 A3|87%] AK 28/30  🧨x2 💊x1
            if (esp_inventory_enabled) {
                UILabel *invLbl = LABEL_FROM_POOL(self.inventoryLabelPool, invIdx); invIdx++;

                NSMutableString *invStr = [NSMutableString string];

                // Helmet level
                if (pInfo.helmetLevel > 0)
                    [invStr appendFormat:@"H%d ", pInfo.helmetLevel];
                else
                    [invStr appendString:@"H- "];

                // Armor level + durability %
                if (pInfo.armorLevel > 0 && pInfo.armorMaxDurability > 0) {
                    int durPct = (int)(100.f * pInfo.armorDurability / pInfo.armorMaxDurability);
                    [invStr appendFormat:@"A%d %d%%  ", pInfo.armorLevel, durPct];
                } else {
                    [invStr appendString:@"A-  "];
                }

                // Weapon + ammo
                if (pInfo.weaponName[0] != '\0') {
                    [invStr appendFormat:@"%s", pInfo.weaponName];
                    if (pInfo.ammoInClip > 0)
                        [invStr appendFormat:@" %d", pInfo.ammoInClip];
                    [invStr appendString:@"  "];
                }

                // Grenades & medkits
                if (pInfo.grenadeCount > 0)
                    [invStr appendFormat:@"G%d ", pInfo.grenadeCount];
                if (pInfo.medkitCount > 0)
                    [invStr appendFormat:@"M%d", pInfo.medkitCount];

                invLbl.text = invStr;
                invLbl.font = [UIFont monospacedSystemFontOfSize:8 weight:UIFontWeightRegular];
                invLbl.textColor = [UIColor colorWithRed:0.9 green:0.95 blue:1 alpha:0.9];
                [invLbl sizeToFit];
                // Place below box bottom
                invLbl.center = CGPointMake(sHead.x, sFoot.y + invLbl.frame.size.height/2 + 2);
                invLbl.hidden = NO;
            }

            // ── SKILLS label ──────────────────────────────────────────
            // Format: [Skill1 CD:3.2s] [Skill2 ▶]
            if (esp_skills_enabled && pInfo.skillCount > 0) {
                UILabel *skLbl = LABEL_FROM_POOL(self.skillLabelPool, skillIdx); skillIdx++;
                NSMutableString *skStr = [NSMutableString string];

                // Use system time estimate: m_CdEndTime is game-time based
                // We use cdEnd - cdStart as total CD, compare ratio for display
                for (int si = 0; si < pInfo.skillCount; si++) {
                    float cdEnd   = pInfo.skillCdEnd[si];
                    float cdStart = pInfo.skillCdStart[si];
                    float totalCD = cdEnd - cdStart;

                    if (si > 0) [skStr appendString:@" | "];

                    // Skill name (truncate to 8 chars)
                    char shortName[9] = {};
                    strncpy(shortName, pInfo.skillName[si], 8);

                    if (pInfo.skillCasting[si]) {
                        [skStr appendFormat:@"%s ▶", shortName];
                    } else if (totalCD > 0.1f) {
                        // CD remaining — display total CD as hint
                        [skStr appendFormat:@"%s CD:%.0fs", shortName, totalCD];
                    } else {
                        [skStr appendFormat:@"%s ✓", shortName];
                    }
                }

                skLbl.text = skStr;
                skLbl.font = [UIFont monospacedSystemFontOfSize:8 weight:UIFontWeightRegular];
                skLbl.textColor = [UIColor colorWithRed:0.4 green:1 blue:0.8 alpha:0.9];
                [skLbl sizeToFit];
                float skY = sFoot.y + (esp_inventory_enabled ? 22.f : 4.f) + skLbl.frame.size.height/2;
                skLbl.center = CGPointMake(sHead.x, skY);
                skLbl.hidden = NO;
            }

            // ── Aimbot candidate ──────────────────────────────────────
            if (aimbot_enabled || aimbot_triggerbot) {
                if (aimbot_ignore_knocked && knocked) continue;
                if (aimbot_ignore_bot && isBot)       continue;
                Vector3 aimPos = (aimbot_bone_index == 1)
                    ? ff_getPosition(ff_getHip(player, task), task)
                    : headPos;
                Vector3 sp = WorldToScreen(aimPos, matrix, w, h);
                if (sp.z > 0) {
                    float dx = sp.x-cx, dy = sp.y-cy;
                    float d  = sqrtf(dx*dx+dy*dy);
                    if (d < aimbot_fov && d < closestDist) {
                        closestDist=d; closestPlayer=player; closestPos=aimPos;
                    }
                }
            }
        }

        #undef LABEL_FROM_POOL

        // ── Commit all layers ─────────────────────────────────────────
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        self.espBoxFillLayer.path          = (drawBoxes && esp_box_fill) ? boxFillPath.CGPath : nil;
        self.espBoxLayer.path              = drawBoxes ? boxPath.CGPath : nil;
        self.espBoxOutlineLayer.path       = (drawBoxes && esp_box_outline) ? boxOutlinePath.CGPath : nil;
        self.espLineLayer.path             = drawLines ? linesPath.CGPath : nil;
        self.espLineOutlineLayer.path      = (drawLines && esp_line_outline) ? lineOutlinePath.CGPath : nil;
        self.espHealthBarLayer.path        = esp_health_bar_enabled ? hpBarPath.CGPath : nil;
        self.espHealthBarOutlineLayer.path = (esp_health_bar_enabled && esp_health_bar_outline) ? hpBarOutPath.CGPath : nil;
        self.snapLineLayer.path            = esp_snapline_enabled ? snapPath.CGPath : nil;
        self.snapLineOutlineLayer.path     = esp_snapline_enabled ? snapOutPath.CGPath : nil;

        // Per-player HP box color — tint entire box layer
        if (esp_box_hp_color && validPlayers > 0) {
            // Single-colour tint: use average of players not practical with batch path
            // Set layer color to orange as neutral readable tint when hp_color on
            self.espBoxLayer.strokeColor = [UIColor colorWithRed:1 green:0.6 blue:0 alpha:1].CGColor;
        } else {
            self.espBoxLayer.strokeColor = [UIColor whiteColor].CGColor;
        }

        [CATransaction commit];
        [CATransaction flush];

        if (!closestPlayer)
            self.aimbotCurrentTarget = 0;

        self.watermarkLabel.text = [NSString stringWithFormat:@(OBF("Players: %d | t.me/g1reev7")), validPlayers];
        [self.watermarkLabel sizeToFit];
        return;
    }

CLEAR_BOXES:
    [self clearAllBoxes];
    self.watermarkLabel.text = @(OBF("FF ESP | t.me/g1reev7"));
    [self.watermarkLabel sizeToFit];
}

- (void)launchGame {
    [[LSApplicationWorkspace defaultWorkspace]
        openApplicationWithBundleID:@(OBF("com.dts.freefireth"))];
}

- (void)startBackgroundKeeper {
    [[AVAudioSession sharedInstance]
        setCategory:AVAudioSessionCategoryPlayback
        withOptions:AVAudioSessionCategoryOptionMixWithOthers
        error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {}

@end

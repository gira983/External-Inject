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
@property (nonatomic, assign) double            aimbotLastWriteTime;
@property (nonatomic, assign) BOOL              triggerbotShooting;
@property (nonatomic, assign) double            triggerbotLastShotTime;
@property (nonatomic, assign) BOOL              isESPCountEnabled;
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
    self.aimbotCurrentTarget    = 0;
    self.aimbotLastWriteTime    = 0;
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
    self.fovCircleLayer.hidden        = YES;
    self.fovCircleOutlineLayer.hidden = YES;
    for (UILabel *l in self.nameLabelPool)   l.hidden = YES;
    for (UILabel *l in self.healthLabelPool) l.hidden = YES;
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

        // ── Client hacks — пишем раз в секунду, не каждый кадр ─────
        static double lastHackWrite = 0;
        double nowHack = CACurrentMediaTime();
        if (nowHack - lastHackWrite > 1.0) {
            lastHackWrite = nowHack;
            uint64_t attrs = Read<uint64_t>(localPlayer + OFF_PLAYER_ATTRS, task);
            if (attrs > 0x1000000) {
                if (esp_inf_ammo)     { Write<bool>(attrs+0xC9,true,task); Write<bool>(attrs+0xC8,true,task); }
                if (esp_speed_boost)    Write<float>(attrs+0x250, 1.8f, task);
                if (esp_damage_boost)   Write<float>(attrs+0x118, 2.0f, task);
                if (esp_instant_skills) Write<float>(attrs+0x188, 0.99f, task);
            }
        }

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

        // ── FOV circle (EzTap style) ──────────────────────────────────
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        if (aimbot_fov_visible) {
            CGPoint center = CGPointMake(w/2, h/2);
            CGFloat radius = aimbot_fov;
            CGRect  cr     = CGRectMake(center.x-radius, center.y-radius, radius*2, radius*2);
            UIBezierPath *fp = [UIBezierPath bezierPathWithOvalInRect:cr];
            self.fovCircleOutlineLayer.path = fp.CGPath;
            self.fovCircleLayer.path        = fp.CGPath;
            self.fovCircleOutlineLayer.hidden = NO;
            self.fovCircleLayer.hidden        = NO;
        } else {
            self.fovCircleOutlineLayer.hidden = YES;
            self.fovCircleLayer.hidden        = YES;
        }
        [CATransaction commit];

        // ── ESP paths (EzTap exact) ───────────────────────────────────
        BOOL drawBoxes = esp_box_enabled || esp_box_fill || esp_box_corner;
        BOOL drawLines = esp_line_enabled;

        UIBezierPath *boxPath        = [UIBezierPath bezierPath];
        UIBezierPath *boxFillPath    = [UIBezierPath bezierPath];
        UIBezierPath *boxOutlinePath = [UIBezierPath bezierPath];
        UIBezierPath *linesPath      = [UIBezierPath bezierPath];
        UIBezierPath *lineOutlinePath= [UIBezierPath bezierPath];
        UIBezierPath *hpBarPath      = [UIBezierPath bezierPath];
        UIBezierPath *hpBarOutPath   = [UIBezierPath bezierPath];

        NSUInteger nameIdx = 0, hpIdx = 0;
        for (UILabel *l in self.nameLabelPool)   l.hidden = YES;
        for (UILabel *l in self.healthLabelPool) l.hidden = YES;

        int validPlayers = 0;
        CGFloat cx = w/2, cy = h/2;
        float closestDist   = FLT_MAX;
        uint64_t closestPlayer = 0;
        Vector3  closestPos    = {0,0,0};

        for (int i = 0; i < total; i++) {
            uint64_t player = Read<uint64_t>(tVal + OFF_PLAYERLIST_ITEM + 8*i, task);
            if (!player || player < 0x1000000 || player == localPlayer) continue;

            // Team check
            if (esp_team_check && ff_isTeammate(localPlayer, player, task)) continue;

            int curHP = ff_getCurHP(player, task);
            int maxHP = ff_getMaxHP(player, task);
            if (maxHP <= 0) continue;

            bool knocked = (curHP <= 0);

            // Ignore knocked
            if (esp_ignore_knocked && knocked) continue;

            // Bot detection — у ботов FF нет записи в PropertyData pool
            bool isBot = false;
            if (esp_ignore_bot || aimbot_ignore_bot) {
                // Боты: ID команды и значения HP берутся из пула
                // Простая проверка: если оба HP = 0 и maxHP стандартный = бот
                uint64_t pool = Read<uint64_t>(player + OFF_IPRIDATAPOOL, task);
                isBot = (pool < 0x1000000); // нет пула данных = бот
            }
            if (esp_ignore_bot && isBot) continue;

            // Head + foot positions
            uint64_t headNode = ff_getHead(player, task);
            if (!headNode || headNode < 0x1000000) continue;
            Vector3 headPos = ff_getPosition(headNode, task);
            if (headPos.x == 0 && headPos.y == 0 && headPos.z == 0) continue;

            uint64_t footNode = ff_getRightAnkle(player, task);
            Vector3  footPos  = (footNode > 0x1000000)
                ? ff_getPosition(footNode, task)
                : (Vector3){headPos.x, headPos.y - 1.7f, headPos.z};

            Vector3 topPos = headPos; topPos.y += 0.18f;
            Vector3 sTop  = WorldToScreen(topPos, matrix, w, h);
            Vector3 sFoot = WorldToScreen(footPos, matrix, w, h);
            Vector3 sHead = WorldToScreen(headPos, matrix, w, h);

            if (sTop.z <= 0) continue;
            if (sTop.x < -200 || sTop.x > w+200 || sTop.y < -200 || sTop.y > h+200) continue;

            float bh = fabsf(sFoot.y - sTop.y);
            if (bh < 5.f) continue;

            float dist = Vector3::Distance(myPos, headPos);
            if (dist > 600.f) continue;

            float bw = bh / 2.0f;
            validPlayers++;

            // ── BOX (EzTap exact) ─────────────────────────────────────
            if (drawBoxes) {
                CGRect rect = CGRectMake(sTop.x - bw/2, sTop.y, bw, bh);
                if (esp_box_fill)
                    [boxFillPath appendPath:[UIBezierPath bezierPathWithRect:rect]];
                if (esp_box_corner) {
                    float cw = bw/4, ch = bh/4;
                    [boxPath moveToPoint:CGPointMake(rect.origin.x,      rect.origin.y+ch)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,   rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+cw,rect.origin.y)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+bw-cw,rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw,rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw,rect.origin.y+ch)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+bw,  rect.origin.y+bh-ch)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw,rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw-cw,rect.origin.y+bh)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+cw,  rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,   rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,   rect.origin.y+bh-ch)];
                    if (esp_box_outline) [boxOutlinePath appendPath:boxPath];
                } else {
                    [boxPath appendPath:[UIBezierPath bezierPathWithRect:rect]];
                    if (esp_box_outline) [boxOutlinePath appendPath:[UIBezierPath bezierPathWithRect:rect]];
                }
            }

            // ── LINES ─────────────────────────────────────────────────
            if (drawLines) {
                [linesPath moveToPoint:CGPointMake(w/2, 0)];
                [linesPath addLineToPoint:CGPointMake(sHead.x, sHead.y)];
                if (esp_line_outline) {
                    [lineOutlinePath moveToPoint:CGPointMake(w/2, 0)];
                    [lineOutlinePath addLineToPoint:CGPointMake(sHead.x, sHead.y)];
                }
            }

            // ── HP BAR (EzTap style) ──────────────────────────────────
            if (esp_health_bar_enabled && maxHP > 0) {
                float ratio  = fmaxf(0, fminf(1, (float)curHP/maxHP));
                float barX   = sTop.x - bw/2 - 5;
                float barTopY= sFoot.y - (bh * ratio);
                float barBotY= sFoot.y;
                [hpBarOutPath moveToPoint:CGPointMake(barX, barBotY)];
                [hpBarOutPath addLineToPoint:CGPointMake(barX, sTop.y)];
                [hpBarPath moveToPoint:CGPointMake(barX, barBotY)];
                [hpBarPath addLineToPoint:CGPointMake(barX, barTopY)];
            }

            // ── NAME ──────────────────────────────────────────────────
            if (esp_name_enabled) {
                UILabel *lbl = nameIdx < self.nameLabelPool.count
                    ? self.nameLabelPool[nameIdx]
                    : ({ UILabel *n=[[UILabel alloc]init]; n.userInteractionEnabled=NO;
                         [self addSubview:n]; [self.nameLabelPool addObject:n]; n; });
                nameIdx++;
                uint64_t namePtr = Read<uint64_t>(player + 0x3C0, task);
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
                    lbl.font=      [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
                    lbl.text=      name;
                    lbl.textColor= [UIColor whiteColor];
                }
                [lbl sizeToFit];
                lbl.center = CGPointMake(sHead.x, sTop.y - 10);
                lbl.hidden = NO;
            }

            // ── HP TEXT ───────────────────────────────────────────────
            if (esp_health_enabled && maxHP > 0) {
                UILabel *hpL = hpIdx < self.healthLabelPool.count
                    ? self.healthLabelPool[hpIdx]
                    : ({ UILabel *n=[[UILabel alloc]init]; n.userInteractionEnabled=NO;
                         [self addSubview:n]; [self.healthLabelPool addObject:n]; n; });
                hpIdx++;
                hpL.text      = [NSString stringWithFormat:@"%d", knocked?0:curHP];
                hpL.font      = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
                hpL.textColor = [UIColor whiteColor];
                [hpL sizeToFit];
                hpL.center = CGPointMake(sHead.x - bw/2 - hpL.frame.size.width/2 - 2,
                                         sTop.y + hpL.frame.size.height/2);
                hpL.hidden = NO;
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

        // ── Commit (EzTap exact) ──────────────────────────────────────
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        self.espBoxFillLayer.path          = (drawBoxes && esp_box_fill) ? boxFillPath.CGPath : nil;
        self.espBoxLayer.path              = drawBoxes ? boxPath.CGPath : nil;
        self.espBoxOutlineLayer.path       = (drawBoxes && esp_box_outline) ? boxOutlinePath.CGPath : nil;
        self.espLineLayer.path             = drawLines ? linesPath.CGPath : nil;
        self.espLineOutlineLayer.path      = (drawLines && esp_line_outline) ? lineOutlinePath.CGPath : nil;
        self.espHealthBarLayer.path        = esp_health_bar_enabled ? hpBarPath.CGPath : nil;
        self.espHealthBarOutlineLayer.path = (esp_health_bar_enabled && esp_health_bar_outline) ? hpBarOutPath.CGPath : nil;
        [CATransaction commit];
        [CATransaction flush];

        // ── Aimbot — throttle 50ms чтобы не банило ──────────────────
        static double lastAimWrite = 0;
        double nowAim = CACurrentMediaTime();
        if (closestPlayer && (aimbot_enabled || aimbot_triggerbot) && nowAim - lastAimWrite > 0.05) {
            lastAimWrite = nowAim;
            [self runAimbot:localPlayer target:closestPlayer targetPos:closestPos task:task matrix:matrix w:w h:h];
        } else if (!closestPlayer) {
            self.aimbotCurrentTarget = 0;
        }

        self.watermarkLabel.text = [NSString stringWithFormat:@(OBF("Players: %d | t.me/g1reev7")), validPlayers];
        [self.watermarkLabel sizeToFit];
        return;
    }

CLEAR_BOXES:
    [self clearAllBoxes];
    self.watermarkLabel.text = @(OBF("FF ESP | t.me/g1reev7"));
    [self.watermarkLabel sizeToFit];
}

// ─── Aimbot — EzTap style, читаем текущий угол из памяти ────────────────────
- (void)runAimbot:(uint64_t)me
           target:(uint64_t)target
        targetPos:(Vector3)targetPos
             task:(task_t)task
           matrix:(float *)matrix
                w:(CGFloat)w h:(CGFloat)h {

    // FOV circle
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (aimbot_fov_visible) {
        CGPoint center = CGPointMake(w/2, h/2);
        CGFloat r = aimbot_fov;
        UIBezierPath *fp = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x-r,center.y-r,r*2,r*2)];
        self.fovCircleOutlineLayer.path = fp.CGPath;
        self.fovCircleLayer.path        = fp.CGPath;
        self.fovCircleOutlineLayer.hidden = NO;
        self.fovCircleLayer.hidden        = NO;
    }
    [CATransaction commit];

    if (!aimbot_enabled) return;

    // Camera position
    uint64_t camT  = Read<uint64_t>(me + OFF_CAMERA_TRANSFORM, task);
    Vector3  camPos = camT > 0x1000000 ? ff_getPosition(camT, task) : (Vector3){0,0,0};

    float dx = targetPos.x - camPos.x;
    float dy = targetPos.y - camPos.y;
    float dz = targetPos.z - camPos.z;
    float dist = sqrtf(dx*dx + dy*dy + dz*dz);
    if (dist < 0.001f) return;

    float tPitch = -asinf(fmaxf(-1.f, fminf(1.f, dy/dist))) * (180.f/M_PI);
    float tYaw   =  atan2f(dx, dz) * (180.f/M_PI);

    // Читаем текущий Quaternion → Euler для плавной интерполяции
    Quaternion q = Read<Quaternion>(me + OFF_ROTATION, task);
    float sinP = 2.f*(q.w*q.x - q.y*q.z);
    float cPitch = asinf(fmaxf(-1.f, fminf(1.f, sinP))) * (180.f/M_PI);
    float sinY   = 2.f*(q.w*q.y + q.z*q.x);
    float cosY   = 1.f - 2.f*(q.y*q.y + q.z*q.z);
    float cYaw   = atan2f(sinY, cosY) * (180.f/M_PI);

    float newPitch, newYaw;
    if (aimbot_smooth <= 1.0f) {
        newPitch = fmaxf(-89.f, fminf(89.f, tPitch));
        newYaw   = tYaw;
    } else {
        // EzTap smooth formula
        float s = 1.0f / (1.0f + aimbot_smooth * 0.5f);
        s = fmaxf(0.03f, fminf(s, 1.0f));
        float dp  = tPitch - cPitch;
        float dy2 = tYaw   - cYaw;
        while (dy2 >  180.f) dy2 -= 360.f;
        while (dy2 < -180.f) dy2 += 360.f;
        newPitch = fmaxf(-89.f, fminf(89.f, cPitch + dp  * s));
        newYaw   = cYaw + dy2 * s;
    }

    // Euler → Quaternion
    float pr = newPitch * (M_PI/180.f) * 0.5f;
    float yr = newYaw   * (M_PI/180.f) * 0.5f;
    Quaternion rot;
    rot.x =  sinf(pr)*cosf(yr);
    rot.y =  cosf(pr)*sinf(yr);
    rot.z = -sinf(pr)*sinf(yr);
    rot.w =  cosf(pr)*cosf(yr);

    // Пишем только камеру (OFF_ROTATION), не пулю (OFF_ROTATION2)
    // OFF_ROTATION2 верифицируется сервером — писать туда = бан
    Write<Quaternion>(me + OFF_ROTATION, rot, task);

    self.aimbotCurrentTarget    = target;
    self.aimbotLastWriteTime    = CACurrentMediaTime();
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

#import "esp.h"
#import "tt.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#include "obfusheader.h"
#import "../../sources/UIView+SecureView.h"
#include <cmath>

// ─── Config globals ───────────────────────────────────────────────────────────
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

// FF client-side hacks
volatile bool esp_inf_ammo       = false;
volatile bool esp_speed_boost    = false;
volatile bool esp_damage_boost   = false;
volatile bool esp_instant_skills = false;

// Aimbot
volatile bool  aimbot_enabled        = false;
volatile bool  aimbot_visible_check  = false;
volatile bool  aimbot_shooting_check = false;
volatile bool  aimbot_team_check     = true;
volatile bool  aimbot_fov_visible    = true;
volatile bool  aimbot_triggerbot     = false;
volatile float aimbot_smooth         = 5.0f;
volatile float aimbot_fov            = 150.0f;
volatile float aimbot_trigger_delay  = 0.1f;
volatile int   aimbot_bone_index     = 0; // 0=head 1=hip

// Kept for config compat
volatile bool  esp_rcs_enabled = false;
volatile float esp_rcs_h       = 0.0f;
volatile float esp_rcs_v       = 0.0f;
volatile bool  esp_auto_load   = false;
NSString *esp_selected_config  = nil;

// ─── Includes ─────────────────────────────────────────────────────────────────
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

// ─── WorldToScreen ────────────────────────────────────────────────────────────
static Vector3 FF_W2S(Vector3 obj, float *m, CGFloat w, CGFloat h) {
    float ww = m[3]*obj.x + m[7]*obj.y + m[11]*obj.z + m[15];
    if (ww < 0.5f) { return {0,0,-1}; }
    float sx = (w/2) + (m[0]*obj.x + m[4]*obj.y + m[8]*obj.z  + m[12]) / ww * (w/2);
    float sy = (h/2) - (m[1]*obj.x + m[5]*obj.y + m[9]*obj.z  + m[13]) / ww * (h/2);
    return {sx, sy, ww};
}

// ─── ESP_View interface ───────────────────────────────────────────────────────
@interface ESP_View ()
@property (nonatomic, strong) CADisplayLink  *displayLinkData;
@property (nonatomic, strong) CAShapeLayer   *espBoxLayer;
@property (nonatomic, strong) CAShapeLayer   *espBoxFillLayer;
@property (nonatomic, strong) CAShapeLayer   *espBoxOutlineLayer;
@property (nonatomic, strong) CAShapeLayer   *espLineLayer;
@property (nonatomic, strong) CAShapeLayer   *espLineOutlineLayer;
@property (nonatomic, strong) CAShapeLayer   *espHealthBarLayer;
@property (nonatomic, strong) CAShapeLayer   *espHealthBarOutlineLayer;
@property (nonatomic, strong) CAShapeLayer   *fovCircleLayer;
@property (nonatomic, strong) CAShapeLayer   *fovCircleOutlineLayer;
@property (nonatomic, strong) NSMutableArray<UILabel *> *nameLabelPool;
@property (nonatomic, strong) NSMutableArray<UILabel *> *healthLabelPool;
@property (nonatomic, strong) UILabel        *watermarkLabel;
@property (nonatomic, assign) uint64_t       aimbotCurrentTarget;
@property (nonatomic, assign) double         aimbotLastWriteTime;
@property (nonatomic, assign) BOOL           hasAttemptedLaunch;
@end

@implementation ESP_View

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor        = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    self.hasAttemptedLaunch     = NO;

    auto addLayer = ^CAShapeLayer *(UIColor *stroke, UIColor *fill, CGFloat lw) {
        CAShapeLayer *l = [CAShapeLayer layer];
        l.strokeColor = stroke.CGColor;
        l.fillColor   = fill.CGColor;
        l.lineWidth   = lw;
        [self.layer addSublayer:l];
        return l;
    };

    self.espBoxFillLayer         = addLayer([UIColor clearColor], [UIColor colorWithWhite:1 alpha:0.15], 0);
    self.espBoxOutlineLayer      = addLayer([UIColor blackColor],  [UIColor clearColor], 3.0);
    self.espBoxLayer             = addLayer([UIColor whiteColor],  [UIColor clearColor], 1.5);
    self.espHealthBarOutlineLayer= addLayer([UIColor blackColor],  [UIColor clearColor], 3.0);
    self.espHealthBarLayer       = addLayer([UIColor colorWithRed:0 green:1 blue:0 alpha:0.85], [UIColor clearColor], 2.0);
    self.espLineOutlineLayer     = addLayer([UIColor blackColor],  [UIColor clearColor], 3.0);
    self.espLineLayer            = addLayer([UIColor whiteColor],  [UIColor clearColor], 1.0);

    self.fovCircleOutlineLayer = [CAShapeLayer layer];
    self.fovCircleOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.fovCircleOutlineLayer.strokeColor = [UIColor colorWithWhite:0 alpha:0.5].CGColor;
    self.fovCircleOutlineLayer.lineWidth   = 3.0;
    self.fovCircleOutlineLayer.hidden      = YES;
    [self.layer addSublayer:self.fovCircleOutlineLayer];

    self.fovCircleLayer = [CAShapeLayer layer];
    self.fovCircleLayer.fillColor   = [UIColor clearColor].CGColor;
    self.fovCircleLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.fovCircleLayer.lineWidth   = 1.5;
    self.fovCircleLayer.hidden      = YES;
    [self.layer addSublayer:self.fovCircleLayer];

    UILabel *wm  = [[UILabel alloc] init];
    wm.text      = @(OBF("FF ESP"));
    wm.textColor = [UIColor whiteColor];
    wm.font      = [UIFont boldSystemFontOfSize:14];
    wm.userInteractionEnabled = NO;
    [self addSubview:wm];
    self.watermarkLabel = wm;

    self.nameLabelPool   = [NSMutableArray new];
    self.healthLabelPool = [NSMutableArray new];
    self.aimbotCurrentTarget = 0;

    self.menuView = [[MenuView alloc] initWithFrame:CGRectMake(0, 0, 270, 310)];
    self.menuView.center = CGPointMake(frame.size.width/2, frame.size.height/2);
    [self addSubview:self.menuView];

    [self startBackgroundKeeper];

    self.displayLinkData = [CADisplayLink displayLinkWithTarget:self selector:@selector(update_data)];
    self.displayLinkData.preferredFramesPerSecond = 60;
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
}

- (void)clearAllBoxes {
    self.espBoxLayer.path              = nil;
    self.espBoxFillLayer.path          = nil;
    self.espBoxOutlineLayer.path       = nil;
    self.espLineLayer.path             = nil;
    self.espLineOutlineLayer.path      = nil;
    self.espHealthBarLayer.path        = nil;
    self.espHealthBarOutlineLayer.path = nil;
    self.fovCircleLayer.hidden         = YES;
    self.fovCircleOutlineLayer.hidden  = YES;
    for (UILabel *l in self.nameLabelPool)   l.hidden = YES;
    for (UILabel *l in self.healthLabelPool) l.hidden = YES;
}

// ─── Main loop ────────────────────────────────────────────────────────────────
- (void)update_data {
    static pid_t             cached_pid  = 0;
    static task_t            cached_task = 0;
    static mach_vm_address_t cached_base = 0;

    pid_t ff_pid = get_pid_by_name(OBF("freefireth"));
    if (ff_pid <= 0) {
        cached_pid = cached_task = cached_base = 0;
        [self clearAllBoxes];
        self.watermarkLabel.text = @(OBF("Waiting for FreeFire..."));
        [self.watermarkLabel sizeToFit];
        if (!self.hasAttemptedLaunch) { [self launchGame]; self.hasAttemptedLaunch = YES; }
        return;
    }

    if (ff_pid != cached_pid || !cached_task || !cached_base) {
        cached_task = get_task_by_pid(ff_pid);
        if (cached_task) cached_base = get_image_base_address(cached_task, OBF("UnityFramework"));
        cached_pid = ff_pid;
    }

    task_t task = cached_task;
    if (!task || !cached_base) goto CLEAR;

    {
        uint64_t matchGame   = ff_getMatchGame(cached_base, task);
        if (!matchGame || matchGame < 0x1000000) goto CLEAR;
        uint64_t match       = ff_getMatch(matchGame, task);
        if (!match || match < 0x1000000) goto CLEAR;
        uint64_t localPlayer = ff_getLocalPlayer(match, task);
        if (!localPlayer || localPlayer < 0x1000000) goto CLEAR;
        uint64_t camera      = ff_getCameraMain(matchGame, task);
        float   *matrix      = camera ? ff_getViewMatrix(camera, task) : nullptr;
        if (!matrix) goto CLEAR;

        // ── Client hacks ──────────────────────────────────────────────
        uint64_t attrs = Read<uint64_t>(localPlayer + OFF_PLAYER_ATTRS, task);
        if (attrs > 0x1000000) {
            if (esp_inf_ammo)       { Write<bool>(attrs+0xC9, true, task); Write<bool>(attrs+0xC8, true, task); }
            if (esp_speed_boost)      Write<float>(attrs+0x250, 1.8f, task);
            if (esp_damage_boost)     Write<float>(attrs+0x118, 2.0f, task);
            if (esp_instant_skills)   Write<float>(attrs+0x188, 0.99f, task);
        }

        // ── Player list ───────────────────────────────────────────────
        uint64_t plPtr   = Read<uint64_t>(match + OFF_PLAYERLIST, task);
        if (!plPtr || plPtr < 0x1000000) goto CLEAR;
        uint64_t plArr   = Read<uint64_t>(plPtr + OFF_PLAYERLIST_ARR, task);
        int      plCount = Read<int>(plPtr + OFF_PLAYERLIST_CNT, task);
        if (plCount <= 0 || plCount > 60 || !plArr) goto CLEAR;

        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;

        // ── FOV circle ────────────────────────────────────────────────
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        if (aimbot_fov_visible && aimbot_enabled) {
            CGFloat r = aimbot_fov;
            UIBezierPath *fp = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(w/2-r, h/2-r, r*2, r*2)];
            self.fovCircleOutlineLayer.path = fp.CGPath;
            self.fovCircleLayer.path        = fp.CGPath;
            self.fovCircleOutlineLayer.hidden = NO;
            self.fovCircleLayer.hidden        = NO;
        } else {
            self.fovCircleOutlineLayer.hidden = YES;
            self.fovCircleLayer.hidden        = YES;
        }
        [CATransaction commit];

        // ── Paths ─────────────────────────────────────────────────────
        UIBezierPath *boxPath    = [UIBezierPath bezierPath];
        UIBezierPath *boxFill    = [UIBezierPath bezierPath];
        UIBezierPath *boxOut     = [UIBezierPath bezierPath];
        UIBezierPath *lines      = [UIBezierPath bezierPath];
        UIBezierPath *linesOut   = [UIBezierPath bezierPath];
        UIBezierPath *hpBar      = [UIBezierPath bezierPath];
        UIBezierPath *hpBarOut   = [UIBezierPath bezierPath];

        NSUInteger nameIdx = 0, hpIdx = 0;
        for (UILabel *l in self.nameLabelPool)   l.hidden = YES;
        for (UILabel *l in self.healthLabelPool) l.hidden = YES;

        int validCount = 0;
        float cx = w/2, cy = h/2;
        float closestDist   = FLT_MAX;
        uint64_t closestTarget = 0;
        Vector3  closestPos    = {0,0,0};

        for (int i = 0; i < plCount && i < 60; i++) {
            uint64_t player = Read<uint64_t>(plArr + OFF_PLAYERLIST_ITEM + i*0x8, task);
            if (!player || player < 0x1000000 || player == localPlayer) continue;
            if (esp_team_check && ff_isTeammate(localPlayer, player, task)) continue;

            int curHP = ff_getCurHP(player, task);
            int maxHP = ff_getMaxHP(player, task);
            if (maxHP <= 0 || curHP <= 0) continue;

            uint64_t headNode = ff_getHead(player, task);
            uint64_t hipNode  = ff_getHip(player, task);
            if (!headNode || !hipNode) continue;

            Vector3 headPos = ff_getPosition(headNode, task);
            Vector3 hipPos  = ff_getPosition(hipNode,  task);
            if (headPos.x == 0 && headPos.y == 0) continue;

            Vector3 sHead = FF_W2S(headPos, matrix, w, h);
            Vector3 sHip  = FF_W2S(hipPos,  matrix, w, h);
            if (sHead.z <= 0 || sHip.z <= 0) continue;
            if (sHip.y <= sHead.y) continue;

            validCount++;
            float bh = sHip.y - sHead.y;
            float bw = bh * 0.55f;

            // BOX
            if (esp_box_enabled || esp_box_fill || esp_box_corner) {
                CGRect rect = CGRectMake(sHead.x - bw/2, sHead.y, bw, bh);
                if (esp_box_fill) [boxFill appendPath:[UIBezierPath bezierPathWithRect:rect]];
                if (esp_box_corner) {
                    float cw = bw/4, ch = bh/4;
                    [boxPath moveToPoint:CGPointMake(rect.origin.x,      rect.origin.y+ch)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,   rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+cw,rect.origin.y)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+bw-cw,rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw,rect.origin.y)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw,rect.origin.y+ch)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+bw,   rect.origin.y+bh-ch)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw,rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x+bw-cw,rect.origin.y+bh)];
                    [boxPath moveToPoint:CGPointMake(rect.origin.x+cw,   rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,   rect.origin.y+bh)];
                    [boxPath addLineToPoint:CGPointMake(rect.origin.x,   rect.origin.y+bh-ch)];
                } else if (esp_box_enabled) {
                    [boxPath appendPath:[UIBezierPath bezierPathWithRect:rect]];
                }
                if (esp_box_outline) [boxOut appendPath:boxPath];
            }

            // LINES
            if (esp_line_enabled) {
                [lines moveToPoint:CGPointMake(w/2, h)];
                [lines addLineToPoint:CGPointMake(sHip.x, sHip.y)];
                if (esp_line_outline) {
                    [linesOut moveToPoint:CGPointMake(w/2, h)];
                    [linesOut addLineToPoint:CGPointMake(sHip.x, sHip.y)];
                }
            }

            // HP BAR
            if (esp_health_bar_enabled) {
                float ratio  = fmaxf(0, fminf(1, (float)curHP / maxHP));
                float barX   = sHead.x - bw/2 - 5;
                float barTop = sHip.y - (bh * ratio);
                [hpBarOut moveToPoint:CGPointMake(barX, sHip.y)];
                [hpBarOut addLineToPoint:CGPointMake(barX, sHead.y)];
                [hpBar moveToPoint:CGPointMake(barX, sHip.y)];
                [hpBar addLineToPoint:CGPointMake(barX, barTop)];
            }

            // NAME
            if (esp_name_enabled) {
                UILabel *lbl = nameIdx < self.nameLabelPool.count
                    ? self.nameLabelPool[nameIdx]
                    : ({ UILabel *n = [[UILabel alloc] init]; n.userInteractionEnabled = NO;
                         [self addSubview:n]; [self.nameLabelPool addObject:n]; n; });
                nameIdx++;
                uint64_t namePtr = Read<uint64_t>(player + 0x3C0, task);
                NSString *name = @"???";
                if (namePtr > 0x1000000) {
                    int len = Read<int>(namePtr + 0x10, task);
                    if (len > 0 && len < 32) {
                        uint16_t buf[32] = {0};
                        mach_vm_size_t out = 0;
                        mach_vm_read_overwrite(task, namePtr+0x14, len*2, (mach_vm_address_t)buf, &out);
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
                    lbl.text = name;
                    lbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
                    lbl.textColor = [UIColor whiteColor];
                }
                [lbl sizeToFit];
                lbl.center = CGPointMake(sHead.x, sHead.y - 10);
                lbl.hidden = NO;
            }

            // HP TEXT
            if (esp_health_enabled) {
                UILabel *hpLbl = hpIdx < self.healthLabelPool.count
                    ? self.healthLabelPool[hpIdx]
                    : ({ UILabel *n = [[UILabel alloc] init]; n.userInteractionEnabled = NO;
                         [self addSubview:n]; [self.healthLabelPool addObject:n]; n; });
                hpIdx++;
                hpLbl.text = [NSString stringWithFormat:@"%d", curHP];
                hpLbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
                hpLbl.textColor = [UIColor whiteColor];
                [hpLbl sizeToFit];
                hpLbl.center = CGPointMake(sHead.x - bw/2 - hpLbl.frame.size.width/2 - 6,
                                           sHead.y + hpLbl.frame.size.height/2);
                hpLbl.hidden = NO;
            }

            // Aimbot candidate
            if (aimbot_enabled || aimbot_triggerbot) {
                uint64_t aimNode = (aimbot_bone_index == 1) ? hipNode : headNode;
                Vector3  aimPos  = ff_getPosition(aimNode, task);
                Vector3  sp      = FF_W2S(aimPos, matrix, w, h);
                if (sp.z > 0) {
                    float dx = sp.x - cx, dy = sp.y - cy;
                    float d  = sqrtf(dx*dx + dy*dy);
                    if (d < aimbot_fov && d < closestDist) {
                        closestDist = d; closestTarget = player; closestPos = aimPos;
                    }
                }
            }
        } // player loop

        // ── Commit paths ──────────────────────────────────────────────
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.espBoxFillLayer.path          = esp_box_fill            ? boxFill.CGPath  : nil;
        self.espBoxLayer.path              = (esp_box_enabled||esp_box_corner) ? boxPath.CGPath : nil;
        self.espBoxOutlineLayer.path       = esp_box_outline         ? boxOut.CGPath   : nil;
        self.espLineLayer.path             = esp_line_enabled        ? lines.CGPath    : nil;
        self.espLineOutlineLayer.path      = (esp_line_enabled&&esp_line_outline) ? linesOut.CGPath : nil;
        self.espHealthBarLayer.path        = esp_health_bar_enabled  ? hpBar.CGPath    : nil;
        self.espHealthBarOutlineLayer.path = (esp_health_bar_enabled&&esp_health_bar_outline) ? hpBarOut.CGPath : nil;
        [CATransaction commit];

        // ── Aimbot write ──────────────────────────────────────────────
        if (closestTarget) {
            self.aimbotCurrentTarget = closestTarget;
            if (aimbot_enabled)
                [self writeAimbot:localPlayer targetPos:closestPos task:task];
        } else {
            self.aimbotCurrentTarget = 0;
        }

        self.watermarkLabel.text = [NSString stringWithFormat:@(OBF("FF ESP | Players: %d")), validCount];
        [self.watermarkLabel sizeToFit];
        return;
    }

CLEAR:
    [self clearAllBoxes];
    self.watermarkLabel.text = @(OBF("FF ESP | No Game"));
    [self.watermarkLabel sizeToFit];
}

// ─── Aimbot ───────────────────────────────────────────────────────────────────
- (void)writeAimbot:(uint64_t)lp targetPos:(Vector3)target task:(task_t)task {
    uint64_t camTrans = Read<uint64_t>(lp + OFF_CAMERA_TRANSFORM, task);
    Vector3  camPos   = camTrans > 0x1000000 ? ff_getPosition(camTrans, task) : (Vector3){0,0,0};

    float dx = target.x - camPos.x;
    float dy = target.y - camPos.y;
    float dz = target.z - camPos.z;
    float dist = sqrtf(dx*dx + dy*dy + dz*dz);
    if (dist < 0.001f) return;

    float tPitch = -asinf(dy/dist) * (180.f/M_PI);
    float tYaw   =  atan2f(dx, dz) * (180.f/M_PI);

    static float cPitch = 0, cYaw = 0;
    if (aimbot_smooth <= 1.0f) {
        cPitch = fmaxf(-89.f, fminf(89.f, tPitch));
        cYaw   = tYaw;
    } else {
        float s  = fmaxf(0.03f, fminf(1.0f / (1.0f + aimbot_smooth*0.5f), 1.0f));
        float dp = tPitch - cPitch;
        float dy2= tYaw   - cYaw;
        while (dy2 >  180.f) dy2 -= 360.f;
        while (dy2 < -180.f) dy2 += 360.f;
        cPitch = fmaxf(-89.f, fminf(89.f, cPitch + dp*s));
        cYaw   = cYaw + dy2*s;
    }

    float pr = cPitch * (M_PI/180.f) * 0.5f;
    float yr = cYaw   * (M_PI/180.f) * 0.5f;
    Quaternion rot;
    rot.x =  sinf(pr)*cosf(yr);
    rot.y =  cosf(pr)*sinf(yr);
    rot.z = -sinf(pr)*sinf(yr);
    rot.w =  cosf(pr)*cosf(yr);

    Write<Quaternion>(lp + OFF_ROTATION,  rot, task);
    Write<Quaternion>(lp + OFF_ROTATION2, rot, task);
}

// ─── Misc ─────────────────────────────────────────────────────────────────────
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

@end

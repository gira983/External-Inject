#import "esp.h"
#import "tt.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#include "obfusheader.h"
#import "../../sources/UIView+SecureView.h"
#include <cmath>
#include <algorithm>

// ─── Config globals ───────────────────────────────────────────────────────────
volatile bool esp_box_enabled        = true;
volatile bool esp_box_outline        = false;
volatile bool esp_box_fill           = false;
volatile bool esp_box_corner         = true;
volatile bool esp_box_3d             = false;
volatile bool esp_line_enabled       = false;
volatile bool esp_line_outline       = false;
volatile bool esp_name_enabled       = true;
volatile bool esp_name_outline       = false;
volatile bool esp_health_enabled     = false;
volatile bool esp_health_bar_enabled = true;
volatile bool esp_health_bar_outline = false;
volatile bool esp_team_check         = true;
volatile bool esp_inf_ammo           = false;
volatile bool esp_speed_boost        = false;
volatile bool esp_damage_boost       = false;
volatile bool esp_instant_skills     = false;
volatile bool aimbot_enabled         = false;
volatile bool aimbot_visible_check   = false;
volatile bool aimbot_shooting_check  = false;
volatile bool aimbot_team_check      = true;
volatile bool aimbot_fov_visible     = true;
volatile bool aimbot_triggerbot      = false;
volatile float aimbot_smooth         = 5.0f;
volatile float aimbot_fov            = 150.0f;
volatile float aimbot_trigger_delay  = 0.1f;
volatile int   aimbot_bone_index     = 0;
volatile bool  esp_rcs_enabled       = false;
volatile float esp_rcs_h             = 0.0f;
volatile float esp_rcs_v             = 0.0f;
volatile bool  esp_auto_load         = false;
NSString      *esp_selected_config   = nil;

// ─── Imports ──────────────────────────────────────────────────────────────────
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
static inline Vector3 W2S(Vector3 p, float *m, float w, float h) {
    float ww = m[3]*p.x + m[7]*p.y + m[11]*p.z + m[15];
    if (ww < 0.01f) return {0, 0, -1};
    return {
        (w * 0.5f) + (m[0]*p.x + m[4]*p.y + m[8]*p.z  + m[12]) / ww * (w * 0.5f),
        (h * 0.5f) - (m[1]*p.x + m[5]*p.y + m[9]*p.z  + m[13]) / ww * (h * 0.5f),
        ww
    };
}

// ─── ESP player snapshot (читаем раз за кадр) ────────────────────────────────
struct PlayerSnap {
    uint64_t ptr;
    Vector3  headPos, footPos;
    Vector3  sHead, sFoot;
    int      curHP, maxHP;
    bool     knocked;
    float    dist;
    NSString *name;
};

// ─── ESP_View ─────────────────────────────────────────────────────────────────
@interface ESP_View ()
@property (nonatomic, strong) CADisplayLink  *displayLink;
@property (nonatomic, strong) CAShapeLayer   *boxLayer;       // все боксы
@property (nonatomic, strong) CAShapeLayer   *boxKnockLayer;  // нокнутые
@property (nonatomic, strong) CAShapeLayer   *hpBgLayer;
@property (nonatomic, strong) CAShapeLayer   *hpFillLayer;
@property (nonatomic, strong) CAShapeLayer   *lineLayer;
@property (nonatomic, strong) CAShapeLayer   *fovLayer;
@property (nonatomic, strong) NSMutableArray<UILabel *> *nameLabelPool;
@property (nonatomic, strong) NSMutableArray<UILabel *> *hpLabelPool;
@property (nonatomic, strong) UILabel        *watermarkLabel;
@property (nonatomic, assign) uint64_t       aimbotTarget;
@property (nonatomic, assign) BOOL           busy;
@end

@implementation ESP_View

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor        = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    self.busy                   = NO;

    auto sl = [&](CGFloat lw, UIColor *sc, UIColor *fc) -> CAShapeLayer* {
        CAShapeLayer *l = [CAShapeLayer layer];
        l.lineWidth   = lw;
        l.strokeColor = sc ? sc.CGColor : [UIColor clearColor].CGColor;
        l.fillColor   = fc ? fc.CGColor : [UIColor clearColor].CGColor;
        l.lineCap     = kCALineCapRound;
        l.lineJoin    = kCALineJoinRound;
        [self.layer addSublayer:l];
        return l;
    };

    self.hpBgLayer    = sl(0, nil, [UIColor colorWithWhite:0 alpha:0.55]);
    self.hpFillLayer  = sl(0, nil, [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1]);
    self.lineLayer    = sl(1.0, [UIColor colorWithWhite:1 alpha:0.55], nil);
    self.boxKnockLayer= sl(1.5, [UIColor colorWithRed:0.7 green:0.5 blue:1 alpha:0.8], nil);
    self.boxLayer     = sl(1.8, [UIColor whiteColor], nil);

    self.fovLayer = [CAShapeLayer layer];
    self.fovLayer.fillColor   = [UIColor clearColor].CGColor;
    self.fovLayer.strokeColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
    self.fovLayer.lineWidth   = 1.2;
    self.fovLayer.lineDashPattern = @[@4, @4];
    self.fovLayer.hidden = YES;
    [self.layer addSublayer:self.fovLayer];

    UILabel *wm  = [[UILabel alloc] init];
    wm.text      = @(OBF("FF ESP  |  t.me/g1reev7"));
    wm.textColor = [UIColor colorWithWhite:1 alpha:0.6];
    wm.font      = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    wm.userInteractionEnabled = NO;
    [self addSubview:wm];
    self.watermarkLabel = wm;

    self.nameLabelPool = [NSMutableArray new];
    self.hpLabelPool   = [NSMutableArray new];
    self.aimbotTarget  = 0;

    self.menuView = [[MenuView alloc] initWithFrame:CGRectMake(0, 0, 270, 310)];
    self.menuView.center = CGPointMake(frame.size.width/2, frame.size.height/2);
    [self addSubview:self.menuView];

    [self startBackgroundKeeper];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(update_data)];
    self.displayLink.preferredFramesPerSecond = 60;
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self showViewForCapture];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) self.frame = self.superview.bounds;
    CGSize s = [self.watermarkLabel sizeThatFits:CGSizeMake(400, 30)];
    self.watermarkLabel.frame = CGRectMake(10, 10, s.width + 4, s.height);
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
    [self.displayLink invalidate];
}

- (void)clearAll {
    self.boxLayer.path       = nil;
    self.boxKnockLayer.path  = nil;
    self.hpBgLayer.path      = nil;
    self.hpFillLayer.path    = nil;
    self.lineLayer.path      = nil;
    self.fovLayer.hidden     = YES;
    for (UILabel *l in self.nameLabelPool) l.hidden = YES;
    for (UILabel *l in self.hpLabelPool)   l.hidden = YES;
}

// ─── Reusable label from pool ─────────────────────────────────────────────────
- (UILabel *)labelFromPool:(NSMutableArray<UILabel *> *)pool index:(NSUInteger)idx {
    if (idx < pool.count) return pool[idx];
    UILabel *l = [[UILabel alloc] init];
    l.userInteractionEnabled = NO;
    [self addSubview:l];
    [pool addObject:l];
    return l;
}

// ─── Main update ──────────────────────────────────────────────────────────────
- (void)update_data {
    // Skip frame if still processing
    if (self.busy) return;
    self.busy = YES;

    static pid_t             cached_pid  = 0;
    static task_t            cached_task = 0;
    static mach_vm_address_t cached_base = 0;

    pid_t ff_pid = get_pid_by_name(OBF("freefireth"));

    if (ff_pid <= 0) {
        cached_pid = 0; cached_task = 0; cached_base = 0;
        [self clearAll];
        self.watermarkLabel.text = @(OBF("FF ESP  |  No Game  |  t.me/g1reev7"));
        [self.watermarkLabel sizeToFit];
        [self launchGame]; // всегда форс-открываем если нет процесса
        self.busy = NO;
        return;
    }

    if (ff_pid != cached_pid || !cached_task || !cached_base) {
        cached_task = get_task_by_pid(ff_pid);
        if (cached_task) {
            mach_vm_address_t vmoff = 0;
            mach_vm_size_t    vmsz  = 0;
            uint32_t          depth = 0;
            struct vm_region_submap_info_64 vbr;
            mach_msg_type_number_t cnt = 16;
            if (mach_vm_region_recurse(cached_task, &vmoff, &vmsz,
                                       &depth, (vm_region_recurse_info_t)&vbr, &cnt) == KERN_SUCCESS)
                cached_base = vmoff;
        }
        cached_pid = ff_pid;
    }

    task_t task = cached_task;
    if (!task || !cached_base) goto CLEAR;

    {
        // ── Chain ─────────────────────────────────────────────────────
        uint64_t matchGame = ff_getMatchGame(cached_base, task);
        if (!matchGame || matchGame < 0x1000000) goto CLEAR;

        uint64_t camera = ff_getCameraMain(matchGame, task);
        if (!camera || camera < 0x1000000) goto CLEAR;

        float *matrix = ff_getViewMatrix(camera, task);
        if (!matrix) goto CLEAR;

        uint64_t match = ff_getMatch(matchGame, task);
        if (!match || match < 0x1000000) goto CLEAR;

        uint64_t me = ff_getLocalPlayer(match, task);
        if (!me || me < 0x1000000) goto CLEAR;

        // My camera position for distance calc
        uint64_t camT  = Read<uint64_t>(me + OFF_CAMERA_TRANSFORM, task);
        Vector3  myPos = (camT > 0x1000000) ? ff_getPosition(camT, task) : (Vector3){0,0,0};

        // ── Client hacks ──────────────────────────────────────────────
        uint64_t attrs = Read<uint64_t>(me + OFF_PLAYER_ATTRS, task);
        if (attrs > 0x1000000) {
            if (esp_inf_ammo)     { Write<bool>(attrs+0xC9, true, task); Write<bool>(attrs+0xC8, true, task); }
            if (esp_speed_boost)    Write<float>(attrs+0x250, 1.8f, task);
            if (esp_damage_boost)   Write<float>(attrs+0x118, 2.0f, task);
            if (esp_instant_skills) Write<float>(attrs+0x188, 0.99f, task);
        }

        // ── Player list ───────────────────────────────────────────────
        uint64_t plPtr  = Read<uint64_t>(match + OFF_PLAYERLIST, task);
        if (!plPtr || plPtr < 0x1000000) goto CLEAR;
        uint64_t tVal   = Read<uint64_t>(plPtr + OFF_PLAYERLIST_ARR, task);
        if (!tVal || tVal < 0x1000000) goto CLEAR;
        int total = Read<int>(tVal + OFF_PLAYERLIST_CNT, task);
        if (total <= 0 || total > 64) total = 64;

        float vW = (float)self.bounds.size.width;
        float vH = (float)self.bounds.size.height;
        if (vW < 10) vW = (float)[UIScreen mainScreen].bounds.size.width;
        if (vH < 10) vH = (float)[UIScreen mainScreen].bounds.size.height;

        // ── FOV ───────────────────────────────────────────────────────
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        if (aimbot_fov_visible && aimbot_enabled) {
            float r = aimbot_fov;
            self.fovLayer.path   = [UIBezierPath bezierPathWithOvalInRect:
                                    CGRectMake(vW/2-r, vH/2-r, r*2, r*2)].CGPath;
            self.fovLayer.hidden = NO;
        } else self.fovLayer.hidden = YES;
        [CATransaction commit];

        // ── Snapshot players ──────────────────────────────────────────
        // Collect all valid players first, then render
        static PlayerSnap snaps[64];
        int snapCount = 0;

        for (int i = 0; i < total && snapCount < 64; i++) {
            uint64_t p = Read<uint64_t>(tVal + OFF_PLAYERLIST_ITEM + 8*i, task);
            if (!p || p < 0x1000000 || p == me) continue;
            if (esp_team_check && ff_isTeammate(me, p, task)) continue;

            int curHP = ff_getCurHP(p, task);
            int maxHP = ff_getMaxHP(p, task);
            if (maxHP <= 0) continue; // нет игрока

            uint64_t headNode = ff_getHead(p, task);
            if (!headNode || headNode < 0x1000000) continue;
            Vector3 headPos = ff_getPosition(headNode, task);
            if (headPos.x == 0 && headPos.y == 0 && headPos.z == 0) continue;

            // Foot: правая щиколотка для точности
            uint64_t footNode = ff_getRightAnkle(p, task);
            Vector3  footPos  = (footNode > 0x1000000) ? ff_getPosition(footNode, task)
                                                       : (Vector3){headPos.x, headPos.y-1.7f, headPos.z};

            // Небольшой отступ над головой для плотного бокса
            Vector3 topPos = headPos; topPos.y += 0.18f;
            Vector3 sTop   = W2S(topPos,  matrix, vW, vH);
            Vector3 sFoot  = W2S(footPos, matrix, vW, vH);

            if (sTop.z <= 0) continue;
            // Отсечение за экраном (с запасом)
            if (sTop.x < -300 || sTop.x > vW+300 || sTop.y < -300 || sTop.y > vH+300) continue;

            float boxH = fabsf(sFoot.y - sTop.y);
            if (boxH < 5.f) continue;

            float dist = Vector3::Distance(myPos, headPos);
            if (dist > 600.f) continue; // дальше 600м — мусор

            PlayerSnap &s = snaps[snapCount++];
            s.ptr     = p;
            s.headPos = headPos;
            s.footPos = footPos;
            s.sHead   = sTop;   // экранная верхняя точка
            s.sFoot   = sFoot;  // экранная нижняя точка
            s.curHP   = curHP;
            s.maxHP   = maxHP;
            s.knocked = (curHP <= 0);
            s.dist    = dist;
            s.name    = nil;

            // Читаем имя только если нужно
            if (esp_name_enabled) {
                uint64_t namePtr = Read<uint64_t>(p + 0x3C0, task);
                if (namePtr > 0x1000000) {
                    int len = Read<int>(namePtr + 0x10, task);
                    if (len > 0 && len < 32) {
                        uint16_t buf[32] = {0};
                        mach_vm_size_t out = 0;
                        mach_vm_read_overwrite(task, namePtr+0x14, len*2, (mach_vm_address_t)buf, &out);
                        s.name = [NSString stringWithCharacters:(unichar*)buf length:(NSUInteger)len];
                    }
                }
                if (!s.name || s.name.length == 0) s.name = @"?";
            }
        }

        // ── Draw ──────────────────────────────────────────────────────
        CGMutablePathRef pBox      = CGPathCreateMutable();
        CGMutablePathRef pBoxKnock = CGPathCreateMutable();
        CGMutablePathRef pHpBg     = CGPathCreateMutable();
        CGMutablePathRef pHpFill   = CGPathCreateMutable();
        CGMutablePathRef pLine     = CGPathCreateMutable();

        NSUInteger nameIdx = 0, hpIdx = 0;
        for (UILabel *l in self.nameLabelPool) l.hidden = YES;
        for (UILabel *l in self.hpLabelPool)   l.hidden = YES;

        float cx = vW/2, cy = vH/2;
        float bestDist = FLT_MAX;
        uint64_t bestTarget = 0;
        Vector3  bestPos    = {0,0,0};

        for (int i = 0; i < snapCount; i++) {
            PlayerSnap &s = snaps[i];

            float boxH = fabsf(s.sFoot.y - s.sHead.y);
            float boxW = boxH * 0.45f;
            float bx   = s.sHead.x - boxW * 0.5f;
            float by   = s.sHead.y;

            CGMutablePathRef target = s.knocked ? pBoxKnock : pBox;

            // ── Box ───────────────────────────────────────────────────
            if (esp_box_enabled && !esp_box_corner) {
                CGPathAddRect(target, nil, CGRectMake(bx, by, boxW, boxH));
            }
            if (esp_box_corner || esp_box_enabled) {
                // Corner brackets — красиво и чисто
                float c = MIN(boxW, boxH) * 0.25f;
                // TL
                CGPathMoveToPoint(target,nil, bx, by+c);
                CGPathAddLineToPoint(target,nil, bx, by);
                CGPathAddLineToPoint(target,nil, bx+c, by);
                // TR
                CGPathMoveToPoint(target,nil, bx+boxW-c, by);
                CGPathAddLineToPoint(target,nil, bx+boxW, by);
                CGPathAddLineToPoint(target,nil, bx+boxW, by+c);
                // BL
                CGPathMoveToPoint(target,nil, bx, by+boxH-c);
                CGPathAddLineToPoint(target,nil, bx, by+boxH);
                CGPathAddLineToPoint(target,nil, bx+c, by+boxH);
                // BR
                CGPathMoveToPoint(target,nil, bx+boxW-c, by+boxH);
                CGPathAddLineToPoint(target,nil, bx+boxW, by+boxH);
                CGPathAddLineToPoint(target,nil, bx+boxW, by+boxH-c);
            }

            // ── HP bar (вертикальная, слева от бокса) ─────────────────
            if (esp_health_bar_enabled && s.maxHP > 0) {
                float ratio  = fmaxf(0.f, fminf(1.f, (float)s.curHP / s.maxHP));
                float barX   = bx - 5.f;
                float barW   = 3.f;
                CGPathAddRect(pHpBg,   nil, CGRectMake(barX, by, barW, boxH));
                if (!s.knocked && ratio > 0) {
                    float fillH = boxH * ratio;
                    CGPathAddRect(pHpFill, nil, CGRectMake(barX, by+boxH-fillH, barW, fillH));
                }
            }

            // ── Lines (от нижнего центра экрана) ──────────────────────
            if (esp_line_enabled) {
                CGPathMoveToPoint(pLine, nil, cx, vH);
                CGPathAddLineToPoint(pLine, nil, s.sFoot.x, s.sFoot.y);
            }

            // ── Name label ────────────────────────────────────────────
            if (esp_name_enabled && s.name) {
                UILabel *lbl = [self labelFromPool:self.nameLabelPool index:nameIdx++];
                lbl.text      = s.name;
                lbl.font      = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
                lbl.textColor = [UIColor whiteColor];
                if (esp_name_outline) {
                    lbl.attributedText = [[NSAttributedString alloc] initWithString:s.name attributes:@{
                        NSFontAttributeName:[UIFont systemFontOfSize:10 weight:UIFontWeightSemibold],
                        NSForegroundColorAttributeName:[UIColor whiteColor],
                        NSStrokeColorAttributeName:[UIColor blackColor],
                        NSStrokeWidthAttributeName:@(-2.5)
                    }];
                }
                [lbl sizeToFit];
                lbl.center = CGPointMake(s.sHead.x, by - lbl.frame.size.height/2 - 3);
                lbl.hidden = NO;
            }

            // ── HP text ───────────────────────────────────────────────
            if (esp_health_enabled && s.maxHP > 0) {
                UILabel *hpLbl = [self labelFromPool:self.hpLabelPool index:hpIdx++];
                float ratio = (float)s.curHP / s.maxHP;
                hpLbl.text = s.knocked ? @"KO" : [NSString stringWithFormat:@"%d", s.curHP];
                hpLbl.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
                hpLbl.textColor = ratio > 0.6f
                    ? [UIColor colorWithRed:0.2 green:0.95 blue:0.45 alpha:1]
                    : ratio > 0.3f
                        ? [UIColor colorWithRed:1 green:0.85 blue:0 alpha:1]
                        : [UIColor colorWithRed:1 green:0.25 blue:0.25 alpha:1];
                [hpLbl sizeToFit];
                hpLbl.center = CGPointMake(bx - 5.f - 1.5f, by + boxH/2);
                hpLbl.hidden = NO;
            }

            // ── Aimbot candidate ──────────────────────────────────────
            if ((aimbot_enabled || aimbot_triggerbot) && !s.knocked) {
                Vector3 aimPos = (aimbot_bone_index == 1)
                    ? ff_getPosition(ff_getHip(s.ptr, task), task)
                    : s.headPos;
                Vector3 sp = W2S(aimPos, matrix, vW, vH);
                if (sp.z > 0) {
                    float dx = sp.x-cx, dy = sp.y-cy;
                    float d  = sqrtf(dx*dx+dy*dy);
                    if (d < aimbot_fov && d < bestDist) {
                        bestDist = d; bestTarget = s.ptr; bestPos = aimPos;
                    }
                }
            }
        }

        // ── Commit ────────────────────────────────────────────────────
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        self.boxLayer.path       = !CGPathIsEmpty(pBox)      ? pBox      : nil;
        self.boxKnockLayer.path  = !CGPathIsEmpty(pBoxKnock) ? pBoxKnock : nil;
        self.hpBgLayer.path      = (esp_health_bar_enabled && !CGPathIsEmpty(pHpBg))   ? pHpBg   : nil;
        self.hpFillLayer.path    = (esp_health_bar_enabled && !CGPathIsEmpty(pHpFill)) ? pHpFill : nil;
        self.lineLayer.path      = (esp_line_enabled && !CGPathIsEmpty(pLine))         ? pLine   : nil;
        [CATransaction commit];

        CGPathRelease(pBox); CGPathRelease(pBoxKnock);
        CGPathRelease(pHpBg); CGPathRelease(pHpFill); CGPathRelease(pLine);

        // ── Aimbot ────────────────────────────────────────────────────
        if (bestTarget && aimbot_enabled)
            [self applyAimbot:me target:bestPos task:task];
        else
            self.aimbotTarget = 0;

        self.watermarkLabel.text = [NSString stringWithFormat:
            @(OBF("FF ESP  |  Players: %d  |  t.me/g1reev7")), snapCount];
        [self.watermarkLabel sizeToFit];
        self.busy = NO;
        return;
    }

CLEAR:
    [self clearAll];
    self.watermarkLabel.text = @(OBF("FF ESP  |  No Game  |  t.me/g1reev7"));
    [self.watermarkLabel sizeToFit];
    self.busy = NO;
}

// ─── Aimbot ───────────────────────────────────────────────────────────────────
- (void)applyAimbot:(uint64_t)me target:(Vector3)target task:(task_t)task {
    uint64_t camT  = Read<uint64_t>(me + OFF_CAMERA_TRANSFORM, task);
    Vector3  camPos = camT > 0x1000000 ? ff_getPosition(camT, task) : (Vector3){0,0,0};

    float dx = target.x-camPos.x, dy = target.y-camPos.y, dz = target.z-camPos.z;
    float dist = sqrtf(dx*dx+dy*dy+dz*dz);
    if (dist < 0.001f) return;

    float tPitch = -asinf(dy/dist) * (180.f/M_PI);
    float tYaw   =  atan2f(dx, dz) * (180.f/M_PI);

    static float cPitch=0, cYaw=0;
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

    float pr = cPitch*(M_PI/180.f)*0.5f;
    float yr = cYaw  *(M_PI/180.f)*0.5f;
    Quaternion rot = {sinf(pr)*cosf(yr), cosf(pr)*sinf(yr),
                     -sinf(pr)*sinf(yr), cosf(pr)*cosf(yr)};
    Write<Quaternion>(me + OFF_ROTATION,  rot, task);
    Write<Quaternion>(me + OFF_ROTATION2, rot, task);
}

// ─── Launch ───────────────────────────────────────────────────────────────────
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

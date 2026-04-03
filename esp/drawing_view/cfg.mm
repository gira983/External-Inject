#import "cfg.h"
#import "tt.h"
#include "obfusheader.h"

NSString *cfg_get_dir() {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir  = [docs stringByAppendingPathComponent:@(OBF("ffesp"))];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

NSArray<NSString*> *cfg_get_list() {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cfg_get_dir() error:nil];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *f in files)
        if ([f hasSuffix:@(OBF(".plist"))])
            [out addObject:[f stringByDeletingPathExtension]];
    return out;
}

void cfg_create(NSString *name) {
    if (!name.length) return;
    NSString *path = [cfg_get_dir() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", name]];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];

    // ESP
    d[@(OBF("esp_box_enabled"))]        = @(esp_box_enabled);
    d[@(OBF("esp_box_outline"))]        = @(esp_box_outline);
    d[@(OBF("esp_box_fill"))]           = @(esp_box_fill);
    d[@(OBF("esp_box_corner"))]         = @(esp_box_corner);
    d[@(OBF("esp_box_3d"))]             = @(esp_box_3d);
    d[@(OBF("esp_line_enabled"))]       = @(esp_line_enabled);
    d[@(OBF("esp_line_outline"))]       = @(esp_line_outline);
    d[@(OBF("esp_team_check"))]         = @(esp_team_check);
    d[@(OBF("esp_name_enabled"))]       = @(esp_name_enabled);
    d[@(OBF("esp_name_outline"))]       = @(esp_name_outline);
    d[@(OBF("esp_health_enabled"))]     = @(esp_health_enabled);
    d[@(OBF("esp_health_bar_enabled"))] = @(esp_health_bar_enabled);
    d[@(OBF("esp_health_bar_outline"))] = @(esp_health_bar_outline);

    // Hacks
    d[@(OBF("esp_inf_ammo"))]           = @(esp_inf_ammo);
    d[@(OBF("esp_speed_boost"))]        = @(esp_speed_boost);
    d[@(OBF("esp_damage_boost"))]       = @(esp_damage_boost);
    d[@(OBF("esp_instant_skills"))]     = @(esp_instant_skills);

    // Aimbot
    d[@(OBF("aimbot_enabled"))]         = @(aimbot_enabled);
    d[@(OBF("aimbot_triggerbot"))]      = @(aimbot_triggerbot);
    d[@(OBF("aimbot_fov_visible"))]     = @(aimbot_fov_visible);
    d[@(OBF("aimbot_visible_check"))]   = @(aimbot_visible_check);
    d[@(OBF("aimbot_shooting_check"))]  = @(aimbot_shooting_check);
    d[@(OBF("aimbot_team_check"))]      = @(aimbot_team_check);
    d[@(OBF("aimbot_smooth"))]          = @(aimbot_smooth);
    d[@(OBF("aimbot_fov"))]             = @(aimbot_fov);
    d[@(OBF("aimbot_trigger_delay"))]   = @(aimbot_trigger_delay);
    d[@(OBF("aimbot_bone_index"))]      = @(aimbot_bone_index);
    d[@(OBF("aimbot_ignore_knocked"))]  = @(aimbot_ignore_knocked);
    d[@(OBF("aimbot_ignore_bot"))]      = @(aimbot_ignore_bot);
    d[@(OBF("esp_ignore_knocked"))]     = @(esp_ignore_knocked);
    d[@(OBF("esp_ignore_bot"))]         = @(esp_ignore_bot);

    [d writeToFile:path atomically:YES];
}

void cfg_load(NSString *name) {
    if (!name.length) return;
    NSString *path = [cfg_get_dir() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", name]];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!d) return;

    #define LOAD_BOOL(key, var)  if (d[@(OBF(key))]) var = [d[@(OBF(key))] boolValue];
    #define LOAD_FLOAT(key, var) if (d[@(OBF(key))]) var = [d[@(OBF(key))] floatValue];
    #define LOAD_INT(key, var)   if (d[@(OBF(key))]) var = [d[@(OBF(key))] intValue];

    LOAD_BOOL("esp_box_enabled",        esp_box_enabled)
    LOAD_BOOL("esp_box_outline",        esp_box_outline)
    LOAD_BOOL("esp_box_fill",           esp_box_fill)
    LOAD_BOOL("esp_box_corner",         esp_box_corner)
    LOAD_BOOL("esp_box_3d",             esp_box_3d)
    LOAD_BOOL("esp_line_enabled",       esp_line_enabled)
    LOAD_BOOL("esp_line_outline",       esp_line_outline)
    LOAD_BOOL("esp_team_check",         esp_team_check)
    LOAD_BOOL("esp_name_enabled",       esp_name_enabled)
    LOAD_BOOL("esp_name_outline",       esp_name_outline)
    LOAD_BOOL("esp_health_enabled",     esp_health_enabled)
    LOAD_BOOL("esp_health_bar_enabled", esp_health_bar_enabled)
    LOAD_BOOL("esp_health_bar_outline", esp_health_bar_outline)
    LOAD_BOOL("esp_inf_ammo",           esp_inf_ammo)
    LOAD_BOOL("esp_speed_boost",        esp_speed_boost)
    LOAD_BOOL("esp_damage_boost",       esp_damage_boost)
    LOAD_BOOL("esp_instant_skills",     esp_instant_skills)
    LOAD_BOOL("aimbot_enabled",         aimbot_enabled)
    LOAD_BOOL("aimbot_triggerbot",      aimbot_triggerbot)
    LOAD_BOOL("aimbot_fov_visible",     aimbot_fov_visible)
    LOAD_BOOL("aimbot_visible_check",   aimbot_visible_check)
    LOAD_BOOL("aimbot_shooting_check",  aimbot_shooting_check)
    LOAD_BOOL("aimbot_team_check",      aimbot_team_check)
    LOAD_FLOAT("aimbot_smooth",         aimbot_smooth)
    LOAD_FLOAT("aimbot_fov",            aimbot_fov)
    LOAD_FLOAT("aimbot_trigger_delay",  aimbot_trigger_delay)
    LOAD_INT("aimbot_bone_index",       aimbot_bone_index)
    LOAD_BOOL("aimbot_ignore_knocked",  aimbot_ignore_knocked)
    LOAD_BOOL("aimbot_ignore_bot",      aimbot_ignore_bot)
    LOAD_BOOL("esp_ignore_knocked",     esp_ignore_knocked)
    LOAD_BOOL("esp_ignore_bot",         esp_ignore_bot)

    #undef LOAD_BOOL
    #undef LOAD_FLOAT
    #undef LOAD_INT
}

void cfg_delete(NSString *name) {
    if (!name.length) return;
    NSString *path = [cfg_get_dir() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", name]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

#import <UIKit/UIKit.h>

// ESP
extern volatile bool esp_box_enabled;
extern volatile bool esp_box_outline;
extern volatile bool esp_box_fill;
extern volatile bool esp_box_corner;
extern volatile bool esp_box_3d;
extern volatile bool esp_line_enabled;
extern volatile bool esp_line_outline;
extern volatile bool esp_name_enabled;
extern volatile bool esp_name_outline;
extern volatile bool esp_health_enabled;
extern volatile bool esp_health_bar_enabled;
extern volatile bool esp_health_bar_outline;
extern volatile bool esp_team_check;

// FF hacks
extern volatile bool esp_inf_ammo;
extern volatile bool esp_speed_boost;
extern volatile bool esp_damage_boost;
extern volatile bool esp_instant_skills;

// Aimbot
extern volatile bool  aimbot_enabled;
extern volatile bool  aimbot_visible_check;
extern volatile bool  aimbot_shooting_check;
extern volatile bool  aimbot_team_check;
extern volatile bool  aimbot_fov_visible;
extern volatile bool  aimbot_triggerbot;
extern volatile float aimbot_smooth;
extern volatile float aimbot_fov;
extern volatile float aimbot_trigger_delay;
extern volatile int   aimbot_bone_index;
extern volatile bool  aimbot_ignore_knocked; // не целиться в нокнутых
extern volatile bool  aimbot_ignore_bot;     // не целиться в ботов

// ESP filters
extern volatile bool  esp_ignore_knocked;
extern volatile bool  esp_ignore_bot;

extern volatile bool  esp_rcs_enabled;
extern volatile float esp_rcs_h;
extern volatile float esp_rcs_v;
extern volatile bool  esp_auto_load;
extern NSString      *esp_selected_config;

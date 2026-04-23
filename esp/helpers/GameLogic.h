#pragma once

#include <stdint.h>
#include "Vector3.h"

// ============================================================
// FF OB53 offsets — verified from ob53 dump cross-reference
// ============================================================

// GameFacade (статик — найди через IDA, меняется каждый патч)
#define OFF_GAMEFACADE_TI       0x0AFF1A58   // TODO: обнови через IDA для ob53
#define OFF_GAMEFACADE_ST       0xB8

// MatchGame chain (не изменились)
#define OFF_MATCH               0x90
#define OFF_CAMERA_MGR          0xD8
#define OFF_CAMERA_MGR2         0x20        // ob52: 0x18 → ob53: 0x20
#define OFF_CAM_V1              0x10
#define OFF_MATRIX_BASE         0xD8

// Match offsets (ob52→ob53: +0x28)
#define OFF_LOCALPLAYER         0xD8        // ob52: 0xB0
#define OFF_PLAYERLIST          0x148       // ob52: 0x120 (Dictionary<byte,Player>)
#define OFF_PLAYERLIST_ARR      0x28
#define OFF_PLAYERLIST_CNT      0x18
#define OFF_PLAYERLIST_ITEM     0x20

// Player — bones (ob52→ob53: +0x88)
#define OFF_BODYPART_POS        0x10
#define OFF_HEAD_NODE           0x640       // ob52: 0x5B8
#define OFF_HIP_NODE            0x648       // ob52: 0x5C0
#define OFF_LEFTANKLE_NODE      0x678       // ob52: 0x5F0
#define OFF_RIGHTANKLE_NODE     0x680       // ob52: 0x5F8
#define OFF_LEFTTOE_NODE        0x688       // ob52: 0x600
#define OFF_RIGHTTOE_NODE       0x690       // ob52: 0x608
#define OFF_LEFTARM_NODE        0x6A8       // ob52: 0x620 (LeftShoulder)
#define OFF_RIGHTARM_NODE       0x6B0       // ob52: 0x628 (RightShoulder)
#define OFF_RIGHTHAND_NODE      0x6B8       // ob52: 0x630
#define OFF_LEFTHAND_NODE       0x6C0       // ob52: 0x638
#define OFF_RIGHTFOREARM_NODE   0x6C8       // ob52: 0x640 (RightElbow)
#define OFF_LEFTFOREARM_NODE    0x6D0       // ob52: 0x648 (LeftElbow)

// Player — identity & HP (ob52→ob53: PlayerID +0x78)
#define OFF_PLAYERID            0x3B0       // ob52: 0x338
#define OFF_IPRIDATAPOOL        0x68        // не изменился
#define OFF_POOL_LIST           0x10
#define OFF_POOL_ITEM           0x20
#define OFF_POOL_VAL            0x18

// Player — rotation & camera (ob52→ob53: +0x78)
#define OFF_ROTATION            0x5B4       // ob52: 0x53C  (<KCFEHMAIINO>k__BackingField)
#define OFF_ROTATION2           0x1834      // ob52: 0x172C (m_CurrentAimRotation)
#define OFF_CAMERA_TRANSFORM    0x390       // ob52: 0x318  (MainCameraTransform)

// Player — name string (ob52→ob53: +0x78)
#define OFF_PLAYER_NAME         0x438       // ob52: 0x3C0 (OIAJCBLDHKP display name)

// Player — attributes, inventory, skills (ob52→ob53: +0x88)
#define OFF_PLAYER_ATTRS        0x708       // ob52: 0x680
#define OFF_INVENTORY_MGR       0x6E0       // ob52: 0x658
#define OFF_SKILL_LIST          0xA50       // ob52: 0x9C8  List<PlayerSkillBase>
#define OFF_ACTIVE_SKILL_LIST   0x11C0      // ob52: 0x1178 List<PlayerActiveSkillBase>

// Player — state (ob52→ob53)
#define OFF_IS_KNOCKED          0x1150      // ob52: 0x1110 (IsKnockedDownBleed)

// InventoryManager (NPCNMJAGIKI) — не изменились
#define OFF_INV_EQUIPPED_ARR    0x88
#define OFF_INV_ITEM_ON_HAND    0xA0
#define OFF_INV_GRENADE_CNT     0xBC
#define OFF_INV_MEDKIT_CNT      0xB4

// Equipment offsets — не изменились
#define OFF_EQUIP_DURABILITY    0x68
#define OFF_EQUIP_DATA          0x80
#define OFF_EQUIPDATA_LEVEL     0x14
#define OFF_EQUIPDATA_MAXDUR    0x28
#define OFF_EQUIPDATA_ITEMDATA  0x58
#define OFF_ITEMDATA_NAME       0x10

// Weapon (GPBDEDFKJNA) — не изменились
#define OFF_WEAPON_DATA         0x90
#define OFF_WEAPON_AMMO         0x560

// ActiveSkill (PFLCPEHBBLN) — не изменились
#define OFF_ASKILL_DATA         0x70
#define OFF_ASKILL_CD_START     0x98
#define OFF_ASKILL_CD_END       0x9C
#define OFF_ASKILL_IS_CASTING   0x8A

// AvatarSkillData — не изменились
#define OFF_ASKILLDATA_NAME     0xB0
#define OFF_ASKILLDATA_TYPE     0xA8

// PlayerAttributes (ob52→ob53: +0x10)
#define OFF_ATTRS_RELOAD_NO_CONSUME 0xD8    // ob52: 0xC8
#define OFF_ATTRS_SHOOT_NO_RELOAD   0xD9    // ob52: 0xC9
#define OFF_ATTRS_DAMAGE_ADD        0x10C   // ob52: 0xFC
#define OFF_ATTRS_WEAPON_DMG        0x128   // ob52: 0x118
#define OFF_ATTRS_AMMO_CLIP         0x134   // ob52: 0x124
#define OFF_ATTRS_SKILL_CD          0x198   // ob52: 0x188
#define OFF_ATTRS_SUPER_ARMOR       0x258   // ob52: 0x248
#define OFF_ATTRS_SPEED             0x260   // ob52: 0x250
#define OFF_ATTRS_GRENADE_RANGE     0x298   // ob52: 0x288
#define OFF_ATTRS_GRENADE_DMG       0x29C   // ob52: 0x28C

// EEquipSlot indices
#define EQUIP_SLOT_HELMET       0
#define EQUIP_SLOT_ARMOR        1
#define EQUIP_SLOT_BAG          2

// ============================================================
// Structs
// ============================================================

struct FFPlayerInfo {
    int     curHP;
    int     maxHP;
    bool    isKnocked;
    bool    isBot;
    int     helmetLevel;
    int     armorLevel;
    int     armorDurability;
    int     armorMaxDurability;
    int     grenadeCount;
    int     medkitCount;
    int     ammoInClip;
    char    weaponName[32];
    int     skillCount;
    float   skillCdEnd[3];
    float   skillCdStart[3];
    bool    skillCasting[3];
    char    skillName[3][32];
};

// ============================================================
// Function declarations
// ============================================================
#import <mach/mach.h>

uint64_t ff_getMatchGame(uint64_t base, task_t task);
uint64_t ff_getMatch(uint64_t matchgame, task_t task);
uint64_t ff_getCameraMain(uint64_t matchgame, task_t task);
float*   ff_getViewMatrix(uint64_t cameraMain, task_t task);
uint64_t ff_getLocalPlayer(uint64_t match, task_t task);
int      ff_getCurHP(uint64_t player, task_t task);
int      ff_getMaxHP(uint64_t player, task_t task);
bool     ff_isTeammate(uint64_t localPlayer, uint64_t player, task_t task);

uint64_t ff_getTransNode(uint64_t bodyPart, task_t task);
uint64_t ff_getHead(uint64_t player, task_t task);
uint64_t ff_getHip(uint64_t player, task_t task);
uint64_t ff_getLeftAnkle(uint64_t player, task_t task);
uint64_t ff_getRightAnkle(uint64_t player, task_t task);
uint64_t ff_getLeftShoulder(uint64_t player, task_t task);
uint64_t ff_getRightShoulder(uint64_t player, task_t task);
uint64_t ff_getLeftElbow(uint64_t player, task_t task);
uint64_t ff_getRightElbow(uint64_t player, task_t task);
uint64_t ff_getLeftHand(uint64_t player, task_t task);
uint64_t ff_getRightHand(uint64_t player, task_t task);
Vector3  ff_getPosition(uint64_t transObj2, task_t task);

uint64_t ff_getInventory(uint64_t player, task_t task);
uint64_t ff_getEquippedItem(uint64_t inventory, int slot, task_t task);
int      ff_getEquipLevel(uint64_t equippedItem, task_t task);
int      ff_getEquipDurability(uint64_t equippedItem, task_t task);
int      ff_getEquipMaxDurability(uint64_t equippedItem, task_t task);
void     ff_getItemName(uint64_t equippedItem, task_t task, char *buf, int bufLen);
uint64_t ff_getWeaponOnHand(uint64_t inventory, task_t task);
int      ff_getAmmoInClip(uint64_t weapon, task_t task);
void     ff_getWeaponName(uint64_t weapon, task_t task, char *buf, int bufLen);
int      ff_getGrenadeCount(uint64_t inventory, task_t task);
int      ff_getMedkitCount(uint64_t inventory, task_t task);
void     ff_readActiveSkills(uint64_t player, task_t task, FFPlayerInfo &info);
void     ff_readPlayerInfo(uint64_t player, uint64_t localPlayer, task_t task, FFPlayerInfo &info);

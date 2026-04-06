#pragma once

#include <stdint.h>
#include "Vector3.h"

// ============================================================
// FF OB52 offsets — verified vs ob51 dump cross-reference
// ============================================================

// GameFacade
#define OFF_GAMEFACADE_TI       0xA4D2968
#define OFF_GAMEFACADE_ST       0xB8

// Match chain
#define OFF_MATCH               0x90
#define OFF_LOCALPLAYER         0xB0
#define OFF_CAMERA_MGR          0xD8
#define OFF_CAMERA_MGR2         0x18
#define OFF_CAM_V1              0x10
#define OFF_MATRIX_BASE         0xD8

// PlayerList
#define OFF_PLAYERLIST          0x120
#define OFF_PLAYERLIST_ARR      0x28
#define OFF_PLAYERLIST_CNT      0x18
#define OFF_PLAYERLIST_ITEM     0x20

// Player — bones (ob51 base + 0x68)
#define OFF_BODYPART_POS        0x10
#define OFF_HEAD_NODE           0x5B8   // HeadNode
#define OFF_HIP_NODE            0x5C0   // HipNode
#define OFF_LEFTANKLE_NODE      0x5F0   // m_LeftAnkleNode
#define OFF_RIGHTANKLE_NODE     0x5F8   // m_RightAnkleNode
#define OFF_LEFTTOE_NODE        0x600   // m_LeftToeNode
#define OFF_RIGHTTOE_NODE       0x608   // m_RightToeNode
#define OFF_LEFTARM_NODE        0x620   // m_LeftArmNode   (LeftShoulder)
#define OFF_RIGHTARM_NODE       0x628   // m_RightArmNode  (RightShoulder)
#define OFF_RIGHTHAND_NODE      0x630   // m_RightHandNode
#define OFF_LEFTHAND_NODE       0x638   // m_LeftHandNode
#define OFF_RIGHTFOREARM_NODE   0x640   // m_RightForeArmNode (RightElbow)
#define OFF_LEFTFOREARM_NODE    0x648   // m_LeftForeArmNode  (LeftElbow)

// Player — identity & HP
#define OFF_PLAYERID            0x338   // IHAAMHPPLMG struct
#define OFF_IPRIDATAPOOL        0x68    // HP PropertyDataPool ptr
#define OFF_POOL_LIST           0x10
#define OFF_POOL_ITEM           0x20
#define OFF_POOL_VAL            0x18

// Player — rotation & camera
#define OFF_ROTATION            0x53C   // <KCFEHMAIINO>k__BackingField = m_AimRotation
#define OFF_ROTATION2           0x172C  // m_CurrentAimRotation
#define OFF_CAMERA_TRANSFORM    0x318   // camera transform pointer

// Player — attributes (JKPFFNEMJIF)
#define OFF_PLAYER_ATTRS        0x680

// Player — InventoryManager (ob51: 0x5F0 + 0x68 = 0x658)
#define OFF_INVENTORY_MGR       0x658   // NPCNMJAGIKI

// Player — skill lists (verified via JJHIMAEGAPA/PFLCPEHBBLN class hierarchy)
#define OFF_SKILL_LIST          0x9C8   // List<PlayerSkillBase>
#define OFF_ACTIVE_SKILL_LIST   0x1178  // List<PlayerActiveSkillBase>

// Player — movement state
#define OFF_IS_KNOCKED          0x1110  // public bool IsKnockedDownBleed
#define OFF_IS_FROZEN_KNOCK     0xA0    // public bool IsFrozenKnockDown (struct offset)

// InventoryManager (NPCNMJAGIKI) offsets
#define OFF_INV_EQUIPPED_ARR    0x88    // AAHMJHHPECM[] m_EquippedItems
#define OFF_INV_ITEM_ON_HAND    0xA0    // AAHMJHHPECM   m_itemOnHand
#define OFF_INV_GRENADE_CNT     0xBC    // int m_GrenadeCount
#define OFF_INV_MEDKIT_CNT      0xB4    // int m_MedkitCount

// Equipment (EGFGOOOBGJB) offsets
#define OFF_EQUIP_DURABILITY    0x68    // int EquipmentDurability
#define OFF_EQUIP_DATA          0x80    // IGDEAGNFNHF ptr (EquipmentData)

// EquipmentData (IGDEAGNFNHF) offsets — same as ob51
#define OFF_EQUIPDATA_LEVEL     0x14    // int iLevel (0=none,1=lv1,2=lv2,3=lv3)
#define OFF_EQUIPDATA_MAXDUR    0x28    // int iDurabilityUpperLimit
#define OFF_EQUIPDATA_ITEMDATA  0x58    // ItemData ptr

// ItemData offsets — same as ob51
#define OFF_ITEMDATA_NAME       0x10    // string strName (C# string)

// Weapon (GPBDEDFKJNA) offsets
#define OFF_WEAPON_DATA         0x90    // NJPAPMEKNPH ptr (WeaponData/FireComponent)
#define OFF_WEAPON_AMMO         0x560   // int m_AmmoLeftInCurrentClip (ob51:0x4C8 + delta 0x98)

// ActiveSkill (PFLCPEHBBLN) offsets
#define OFF_ASKILL_DATA         0x70    // ActiveSkillData ptr
#define OFF_ASKILL_CD_START     0x98    // float m_CdStartTime
#define OFF_ASKILL_CD_END       0x9C    // float m_CdEndTime
#define OFF_ASKILL_IS_CASTING   0x8A    // bool m_IsSkillCasting

// AvatarSkillData offsets — same in ob52 (strings not obfuscated)
#define OFF_ASKILLDATA_NAME     0xB0    // string SkillName
#define OFF_ASKILLDATA_TYPE     0xA8    // string SkillType

// PlayerAttributes (JKPFFNEMJIF) offsets — verified ob52
#define OFF_ATTRS_RELOAD_NO_CONSUME 0xC8  // bool ReloadNoConsumeAmmoclip
#define OFF_ATTRS_SHOOT_NO_RELOAD   0xC9  // bool ShootNoReload
#define OFF_ATTRS_DAMAGE_ADD        0xFC  // float DamageAdditionScale
#define OFF_ATTRS_WEAPON_DMG        0x118 // float BuffWeaponDamageScale
#define OFF_ATTRS_AMMO_CLIP         0x124 // int   BuffWeaponAmmoClip
#define OFF_ATTRS_SKILL_CD          0x188 // float ActiveSkillCdReduction
#define OFF_ATTRS_SUPER_ARMOR       0x248 // bool  IsSuperArmorEnable
#define OFF_ATTRS_SPEED             0x250 // float RunSpeedUpScale
#define OFF_ATTRS_GRENADE_RANGE     0x288 // float MainGrenadeRangeScale
#define OFF_ATTRS_GRENADE_DMG       0x28C // float MainGrenadeDamageScale

// EEquipSlot indices (ob51 verified)
#define EQUIP_SLOT_HELMET       0       // index in m_EquippedItems array
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
    // Inventory
    int     helmetLevel;      // 0 = no helmet
    int     armorLevel;       // 0 = no armor
    int     armorDurability;
    int     armorMaxDurability;
    int     grenadeCount;
    int     medkitCount;
    int     ammoInClip;
    // Weapon name (up to 31 chars)
    char    weaponName[32];
    // Active skills (up to 3)
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

// Core chain
uint64_t ff_getMatchGame(uint64_t base, task_t task);
uint64_t ff_getMatch(uint64_t matchgame, task_t task);
uint64_t ff_getCameraMain(uint64_t matchgame, task_t task);
float*   ff_getViewMatrix(uint64_t cameraMain, task_t task);
uint64_t ff_getLocalPlayer(uint64_t match, task_t task);

// HP
int      ff_getCurHP(uint64_t player, task_t task);
int      ff_getMaxHP(uint64_t player, task_t task);

// Team
bool     ff_isTeammate(uint64_t localPlayer, uint64_t player, task_t task);

// Bones
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

// Position
Vector3  ff_getPosition(uint64_t transObj2, task_t task);

// ── NEW: Inventory & Equipment ────────────────────────────────────────────────
// Returns pointer to InventoryManager for a player
uint64_t ff_getInventory(uint64_t player, task_t task);

// Returns equipped item ptr at slot index (0=helmet, 1=armor, 2=bag)
uint64_t ff_getEquippedItem(uint64_t inventory, int slot, task_t task);

// Returns equipment level (1-3), 0 if not equipped
int      ff_getEquipLevel(uint64_t equippedItem, task_t task);

// Returns current durability of equipped item
int      ff_getEquipDurability(uint64_t equippedItem, task_t task);

// Returns max durability of equipped item
int      ff_getEquipMaxDurability(uint64_t equippedItem, task_t task);

// Reads ItemData.strName from an equipped item into buf (max 31 chars)
void     ff_getItemName(uint64_t equippedItem, task_t task, char *buf, int bufLen);

// Returns weapon currently on hand (0 if none / melee)
uint64_t ff_getWeaponOnHand(uint64_t inventory, task_t task);

// Returns ammo count in current clip
int      ff_getAmmoInClip(uint64_t weapon, task_t task);

// Reads weapon name into buf via ItemData chain
void     ff_getWeaponName(uint64_t weapon, task_t task, char *buf, int bufLen);

// Returns grenade count
int      ff_getGrenadeCount(uint64_t inventory, task_t task);

// Returns medkit count
int      ff_getMedkitCount(uint64_t inventory, task_t task);

// ── NEW: Skills ───────────────────────────────────────────────────────────────
// Fills FFPlayerInfo.skill* fields — reads up to 3 active skills
void     ff_readActiveSkills(uint64_t player, task_t task, FFPlayerInfo &info);

// Returns current game time (from first active skill's m_CdStartTime base)
float    ff_getGameTime(task_t task);

// ── NEW: Full player info (one call fills entire FFPlayerInfo struct) ─────────
void     ff_readPlayerInfo(uint64_t player, uint64_t localPlayer, task_t task, FFPlayerInfo &info);

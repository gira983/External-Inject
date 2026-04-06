#import "GameLogic.h"
#import "pid.h"
#import <mach/mach.h>

// ============================================================
// Internal structs
// ============================================================

struct COW_GamePlay_PlayerID_o {
    uint32_t m_Value;
    uint32_t m_ID;
    uint8_t  m_TeamID;
    uint8_t  m_ShortID;
    uint64_t m_IDMask;
};

struct TMatrix {
    float px, py, pz, pw;
    float rx, ry, rz, rw;
    float sx, sy, sz, sw;
};

// ============================================================
// Helpers
// ============================================================

// Read C# string (UTF-16) from pointer into ASCII/UTF8 buf
static void ff_readCSharpString(uint64_t strPtr, task_t task, char *buf, int bufLen) {
    buf[0] = '\0';
    if (!strPtr || strPtr < 0x1000000) return;
    int len = Read<int>(strPtr + 0x10, task);
    if (len <= 0 || len >= bufLen) return;
    uint16_t tmp[64] = {0};
    if (len > 63) len = 63;
    mach_vm_size_t out = 0;
    kern_return_t kr = mach_vm_read_overwrite(task, strPtr + 0x14,
                                               len * 2,
                                               (mach_vm_address_t)tmp, &out);
    if (kr != KERN_SUCCESS) return;
    // Downcast UTF-16 to ASCII (FF names are ASCII)
    for (int i = 0; i < len && i < bufLen - 1; i++)
        buf[i] = (tmp[i] < 128) ? (char)tmp[i] : '?';
    buf[len] = '\0';
}

// ============================================================
// Position from transform hierarchy
// ============================================================

Vector3 ff_getPosition(uint64_t transObj2, task_t task) {
    uint64_t transObj    = Read<uint64_t>(transObj2 + 0x10, task);
    if (!transObj) return {0,0,0};

    uint64_t matrix        = Read<uint64_t>(transObj + 0x38, task);
    int      index         = Read<int>(transObj + 0x40, task);
    uint64_t matrix_list   = Read<uint64_t>(matrix + 0x18, task);
    uint64_t matrix_indices= Read<uint64_t>(matrix + 0x20, task);
    if (!matrix_list || !matrix_indices) return {0,0,0};

    Vector3 result = Read<Vector3>(matrix_list + sizeof(TMatrix) * index, task);
    int transformIndex = Read<int>(matrix_indices + sizeof(int) * index, task);

    int safety = 50;
    while (transformIndex >= 0 && safety-- > 0) {
        TMatrix tm = Read<TMatrix>(matrix_list + sizeof(TMatrix) * transformIndex, task);
        float rx = tm.rx, ry = tm.ry, rz = tm.rz, rw = tm.rw;
        float sx = result.x * tm.sx;
        float sy = result.y * tm.sy;
        float sz = result.z * tm.sz;
        result.x = tm.px + sx + (sx*(ry*ry*-2.f - rz*rz*2.f))
                        + (sy*(rw*rz*-2.f - ry*rx*-2.f))
                        + (sz*(rz*rx*2.f  - rw*ry*-2.f));
        result.y = tm.py + sy + (sx*(rx*ry*2.f  - rw*rz*-2.f))
                        + (sy*(rz*rz*-2.f - rx*rx*2.f))
                        + (sz*(rw*rx*-2.f - rz*ry*-2.f));
        result.z = tm.pz + sz + (sx*(rw*ry*-2.f - rx*rz*-2.f))
                        + (sy*(ry*rz*2.f  - rw*rx*-2.f))
                        + (sz*(rx*rx*-2.f - ry*ry*2.f));
        transformIndex = Read<int>(matrix_indices + sizeof(int) * transformIndex, task);
    }
    return result;
}

// ============================================================
// Game chain
// ============================================================

uint64_t ff_getMatchGame(uint64_t base, task_t task) {
    uint64_t typeInfo  = Read<uint64_t>(base + OFF_GAMEFACADE_TI, task);
    uint64_t staticPtr = Read<uint64_t>(typeInfo + OFF_GAMEFACADE_ST, task);
    return Read<uint64_t>(staticPtr, task);
}

uint64_t ff_getMatch(uint64_t matchgame, task_t task) {
    return Read<uint64_t>(matchgame + OFF_MATCH, task);
}

uint64_t ff_getCameraMain(uint64_t matchgame, task_t task) {
    uint64_t mgr = Read<uint64_t>(matchgame + OFF_CAMERA_MGR, task);
    return Read<uint64_t>(mgr + OFF_CAMERA_MGR2, task);
}

static float g_matrix[16];
float* ff_getViewMatrix(uint64_t cameraMain, task_t task) {
    uint64_t v1 = Read<uint64_t>(cameraMain + OFF_CAM_V1, task);
    for (int i = 0; i < 16; i++)
        g_matrix[i] = Read<float>(v1 + OFF_MATRIX_BASE + i * 0x4, task);
    return g_matrix;
}

uint64_t ff_getLocalPlayer(uint64_t match, task_t task) {
    return Read<uint64_t>(match + OFF_LOCALPLAYER, task);
}

// ============================================================
// HP via PropertyDataPool
// ============================================================

static int ff_getDataUInt16(uint64_t player, int varID, task_t task) {
    uint64_t pool = Read<uint64_t>(player + OFF_IPRIDATAPOOL, task);
    if (!pool || pool < 0x100000000ULL) return 0;
    uint64_t list = Read<uint64_t>(pool + OFF_POOL_LIST, task);
    uint64_t item = Read<uint64_t>(list + 0x8 * varID + OFF_POOL_ITEM, task);
    return Read<int>(item + OFF_POOL_VAL, task);
}

int ff_getCurHP(uint64_t player, task_t task) { return ff_getDataUInt16(player, 0, task); }
int ff_getMaxHP(uint64_t player, task_t task) { return ff_getDataUInt16(player, 1, task); }

// ============================================================
// Team check
// ============================================================

bool ff_isTeammate(uint64_t localPlayer, uint64_t player, task_t task) {
    COW_GamePlay_PlayerID_o myID = Read<COW_GamePlay_PlayerID_o>(localPlayer + OFF_PLAYERID, task);
    COW_GamePlay_PlayerID_o pid  = Read<COW_GamePlay_PlayerID_o>(player + OFF_PLAYERID, task);
    return myID.m_TeamID == pid.m_TeamID;
}

// ============================================================
// Bone helpers
// ============================================================

uint64_t ff_getTransNode(uint64_t bodyPart, task_t task) {
    return Read<uint64_t>(bodyPart + OFF_BODYPART_POS, task);
}

uint64_t ff_getHead(uint64_t p, task_t t)          { return ff_getTransNode(Read<uint64_t>(p + OFF_HEAD_NODE, t), t); }
uint64_t ff_getHip(uint64_t p, task_t t)           { return ff_getTransNode(Read<uint64_t>(p + OFF_HIP_NODE, t), t); }
uint64_t ff_getLeftAnkle(uint64_t p, task_t t)     { return ff_getTransNode(Read<uint64_t>(p + OFF_LEFTANKLE_NODE, t), t); }
uint64_t ff_getRightAnkle(uint64_t p, task_t t)    { return ff_getTransNode(Read<uint64_t>(p + OFF_RIGHTANKLE_NODE, t), t); }
uint64_t ff_getLeftShoulder(uint64_t p, task_t t)  { return ff_getTransNode(Read<uint64_t>(p + OFF_LEFTARM_NODE, t), t); }
uint64_t ff_getRightShoulder(uint64_t p, task_t t) { return ff_getTransNode(Read<uint64_t>(p + OFF_RIGHTARM_NODE, t), t); }
uint64_t ff_getLeftElbow(uint64_t p, task_t t)     { return ff_getTransNode(Read<uint64_t>(p + OFF_LEFTFOREARM_NODE, t), t); }
uint64_t ff_getRightElbow(uint64_t p, task_t t)    { return ff_getTransNode(Read<uint64_t>(p + OFF_RIGHTFOREARM_NODE, t), t); }
uint64_t ff_getLeftHand(uint64_t p, task_t t)      { return ff_getTransNode(Read<uint64_t>(p + OFF_LEFTHAND_NODE, t), t); }
uint64_t ff_getRightHand(uint64_t p, task_t t)     { return ff_getTransNode(Read<uint64_t>(p + OFF_RIGHTHAND_NODE, t), t); }

// ============================================================
// Inventory
// ============================================================

uint64_t ff_getInventory(uint64_t player, task_t task) {
    return Read<uint64_t>(player + OFF_INVENTORY_MGR, task);
}

// m_EquippedItems is a managed C# array:
// ptr → [object header 0x10] → element[0] @ 0x20, element[1] @ 0x28 ...
uint64_t ff_getEquippedItem(uint64_t inventory, int slot, task_t task) {
    if (!inventory || inventory < 0x1000000) return 0;
    uint64_t arr = Read<uint64_t>(inventory + OFF_INV_EQUIPPED_ARR, task);
    if (!arr || arr < 0x1000000) return 0;
    // C# object array: items start at offset 0x20, each 8 bytes
    return Read<uint64_t>(arr + 0x20 + slot * 0x8, task);
}

int ff_getEquipLevel(uint64_t item, task_t task) {
    if (!item || item < 0x1000000) return 0;
    uint64_t data = Read<uint64_t>(item + OFF_EQUIP_DATA, task);
    if (!data || data < 0x1000000) return 0;
    return Read<int>(data + OFF_EQUIPDATA_LEVEL, task);
}

int ff_getEquipDurability(uint64_t item, task_t task) {
    if (!item || item < 0x1000000) return 0;
    return Read<int>(item + OFF_EQUIP_DURABILITY, task);
}

int ff_getEquipMaxDurability(uint64_t item, task_t task) {
    if (!item || item < 0x1000000) return 0;
    uint64_t data = Read<uint64_t>(item + OFF_EQUIP_DATA, task);
    if (!data || data < 0x1000000) return 0;
    return Read<int>(data + OFF_EQUIPDATA_MAXDUR, task);
}

void ff_getItemName(uint64_t item, task_t task, char *buf, int bufLen) {
    buf[0] = '\0';
    if (!item || item < 0x1000000) return;
    uint64_t equipData = Read<uint64_t>(item + OFF_EQUIP_DATA, task);
    if (!equipData || equipData < 0x1000000) return;
    uint64_t itemData  = Read<uint64_t>(equipData + OFF_EQUIPDATA_ITEMDATA, task);
    if (!itemData || itemData < 0x1000000) return;
    uint64_t nameStr   = Read<uint64_t>(itemData + OFF_ITEMDATA_NAME, task);
    ff_readCSharpString(nameStr, task, buf, bufLen);
}

// ============================================================
// Weapon
// ============================================================

uint64_t ff_getWeaponOnHand(uint64_t inventory, task_t task) {
    if (!inventory || inventory < 0x1000000) return 0;
    return Read<uint64_t>(inventory + OFF_INV_ITEM_ON_HAND, task);
}

int ff_getAmmoInClip(uint64_t weapon, task_t task) {
    if (!weapon || weapon < 0x1000000) return 0;
    return Read<int>(weapon + OFF_WEAPON_AMMO, task);
}

void ff_getWeaponName(uint64_t weapon, task_t task, char *buf, int bufLen) {
    buf[0] = '\0';
    if (!weapon || weapon < 0x1000000) return;
    // Weapon → NJPAPMEKNPH @ 0x90 → ItemData chain not confirmed
    // Fallback: read via EquipmentData chain same as equipment
    uint64_t equipData = Read<uint64_t>(weapon + OFF_EQUIP_DATA, task);
    if (!equipData || equipData < 0x1000000) return;
    uint64_t itemData  = Read<uint64_t>(equipData + OFF_EQUIPDATA_ITEMDATA, task);
    if (!itemData || itemData < 0x1000000) return;
    uint64_t nameStr   = Read<uint64_t>(itemData + OFF_ITEMDATA_NAME, task);
    ff_readCSharpString(nameStr, task, buf, bufLen);
}

// ============================================================
// Consumables
// ============================================================

int ff_getGrenadeCount(uint64_t inventory, task_t task) {
    if (!inventory || inventory < 0x1000000) return 0;
    return Read<int>(inventory + OFF_INV_GRENADE_CNT, task);
}

int ff_getMedkitCount(uint64_t inventory, task_t task) {
    if (!inventory || inventory < 0x1000000) return 0;
    return Read<int>(inventory + OFF_INV_MEDKIT_CNT, task);
}

// ============================================================
// Active skills
// ============================================================

void ff_readActiveSkills(uint64_t player, task_t task, FFPlayerInfo &info) {
    info.skillCount = 0;
    uint64_t listPtr = Read<uint64_t>(player + OFF_ACTIVE_SKILL_LIST, task);
    if (!listPtr || listPtr < 0x1000000) return;

    // C# List<T>: _items array @ 0x10, _size @ 0x18
    uint64_t items = Read<uint64_t>(listPtr + 0x10, task);
    int      size  = Read<int>(listPtr + 0x18, task);
    if (!items || items < 0x1000000 || size <= 0) return;
    if (size > 3) size = 3;

    for (int i = 0; i < size; i++) {
        uint64_t skill = Read<uint64_t>(items + 0x20 + i * 0x8, task);
        if (!skill || skill < 0x1000000) continue;

        info.skillCdStart[i]  = Read<float>(skill + OFF_ASKILL_CD_START, task);
        info.skillCdEnd[i]    = Read<float>(skill + OFF_ASKILL_CD_END,   task);
        info.skillCasting[i]  = Read<bool> (skill + OFF_ASKILL_IS_CASTING, task);

        // SkillName via AvatarSkillData
        info.skillName[i][0] = '\0';
        uint64_t skillData   = Read<uint64_t>(skill + OFF_ASKILL_DATA, task);
        if (skillData > 0x1000000) {
            uint64_t nameStr = Read<uint64_t>(skillData + OFF_ASKILLDATA_NAME, task);
            ff_readCSharpString(nameStr, task, info.skillName[i], 32);
        }
        info.skillCount++;
    }
}

// ============================================================
// Full player info — one call reads everything
// ============================================================

void ff_readPlayerInfo(uint64_t player, uint64_t localPlayer, task_t task, FFPlayerInfo &info) {
    // HP
    info.curHP    = ff_getCurHP(player, task);
    info.maxHP    = ff_getMaxHP(player, task);
    info.isKnocked= (info.curHP <= 0);

    // Bot detection
    uint64_t pool = Read<uint64_t>(player + OFF_IPRIDATAPOOL, task);
    info.isBot = (pool < 0x1000000);

    // Init defaults
    info.helmetLevel      = 0;
    info.armorLevel       = 0;
    info.armorDurability  = 0;
    info.armorMaxDurability= 0;
    info.grenadeCount     = 0;
    info.medkitCount      = 0;
    info.ammoInClip       = 0;
    info.weaponName[0]    = '\0';
    info.skillCount       = 0;

    uint64_t inv = ff_getInventory(player, task);
    if (inv && inv > 0x1000000) {
        // Helmet
        uint64_t helmet = ff_getEquippedItem(inv, EQUIP_SLOT_HELMET, task);
        if (helmet > 0x1000000)
            info.helmetLevel = ff_getEquipLevel(helmet, task);

        // Armor
        uint64_t armor = ff_getEquippedItem(inv, EQUIP_SLOT_ARMOR, task);
        if (armor > 0x1000000) {
            info.armorLevel         = ff_getEquipLevel(armor, task);
            info.armorDurability    = ff_getEquipDurability(armor, task);
            info.armorMaxDurability = ff_getEquipMaxDurability(armor, task);
        }

        // Weapon on hand
        uint64_t weapon = ff_getWeaponOnHand(inv, task);
        if (weapon > 0x1000000) {
            info.ammoInClip = ff_getAmmoInClip(weapon, task);
            ff_getWeaponName(weapon, task, info.weaponName, 32);
        }

        // Consumables
        info.grenadeCount = ff_getGrenadeCount(inv, task);
        info.medkitCount  = ff_getMedkitCount(inv, task);
    }

    // Skills
    ff_readActiveSkills(player, task, info);
}

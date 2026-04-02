#import "GameLogic.h"
#import "pid.h"

// --- Structs ---
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

// --- Position from transform hierarchy ---
Vector3 ff_getPosition(uint64_t transObj2, task_t task) {
    uint64_t transObj = Read<uint64_t>(transObj2 + 0x10, task);
    if (!transObj) return {0,0,0};

    uint64_t matrix       = Read<uint64_t>(transObj + 0x38, task);
    int      index        = Read<int>(transObj + 0x40, task);
    uint64_t matrix_list  = Read<uint64_t>(matrix + 0x18, task);
    uint64_t matrix_indices = Read<uint64_t>(matrix + 0x20, task);
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
        result.x = tm.px + sx + (sx*(ry*ry*-2.f - rz*rz*2.f)) + (sy*(rw*rz*-2.f - ry*rx*-2.f)) + (sz*(rz*rx*2.f - rw*ry*-2.f));
        result.y = tm.py + sy + (sx*(rx*ry*2.f - rw*rz*-2.f)) + (sy*(rz*rz*-2.f - rx*rx*2.f)) + (sz*(rw*rx*-2.f - rz*ry*-2.f));
        result.z = tm.pz + sz + (sx*(rw*ry*-2.f - rx*rz*-2.f)) + (sy*(ry*rz*2.f - rw*rx*-2.f)) + (sz*(rx*rx*-2.f - ry*ry*2.f));
        transformIndex = Read<int>(matrix_indices + sizeof(int) * transformIndex, task);
    }
    return result;
}

// --- Game chain ---
uint64_t ff_getMatchGame(uint64_t base, task_t task) {
    uint64_t typeInfo = Read<uint64_t>(base + OFF_GAMEFACADE_TI, task);
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

// --- HP via PropertyData pool ---
static int ff_getDataUInt16(uint64_t player, int varID, task_t task) {
    uint64_t pool = Read<uint64_t>(player + OFF_IPRIDATAPOOL, task);
    if (!pool || pool < 0x100000000ULL) return 0;
    uint64_t list = Read<uint64_t>(pool + OFF_POOL_LIST, task);
    uint64_t item = Read<uint64_t>(list + 0x8 * varID + OFF_POOL_ITEM, task);
    return Read<int>(item + OFF_POOL_VAL, task);
}

int ff_getCurHP(uint64_t player, task_t task) { return ff_getDataUInt16(player, 0, task); }
int ff_getMaxHP(uint64_t player, task_t task) { return ff_getDataUInt16(player, 1, task); }

bool ff_isTeammate(uint64_t localPlayer, uint64_t player, task_t task) {
    COW_GamePlay_PlayerID_o myID = Read<COW_GamePlay_PlayerID_o>(localPlayer + OFF_PLAYERID, task);
    COW_GamePlay_PlayerID_o pid  = Read<COW_GamePlay_PlayerID_o>(player + OFF_PLAYERID, task);
    return myID.m_TeamID == pid.m_TeamID;
}

// --- Bone helpers ---
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

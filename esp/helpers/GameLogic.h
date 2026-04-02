#pragma once

#include <stdint.h>
#include "Vector3.h"

// --- FF offsets (verified from dump) ---
// GameFacade
#define OFF_GAMEFACADE_TI   0xA4D2968
#define OFF_GAMEFACADE_ST   0xB8
// Match
#define OFF_MATCH           0x90
#define OFF_LOCALPLAYER     0xB0
#define OFF_CAMERA_MGR      0xD8
#define OFF_CAMERA_MGR2     0x18
#define OFF_CAM_V1          0x10
#define OFF_MATRIX_BASE     0xD8
// PlayerList
#define OFF_PLAYERLIST      0x120
#define OFF_PLAYERLIST_ARR  0x28
#define OFF_PLAYERLIST_CNT  0x18
#define OFF_PLAYERLIST_ITEM 0x20
// Player nodes
#define OFF_BODYPART_POS    0x10
#define OFF_HEAD_NODE       0x5B8
#define OFF_HIP_NODE        0x5C0
#define OFF_LEFTANKLE_NODE  0x5F0
#define OFF_RIGHTANKLE_NODE 0x5F8
#define OFF_RIGHTTOE_NODE   0x608
#define OFF_LEFTFOOT_NODE   0x600
#define OFF_LEFTARM_NODE    0x620
#define OFF_RIGHTARM_NODE   0x628
#define OFF_RIGHTHAND_NODE  0x630
#define OFF_LEFTHAND_NODE   0x638
#define OFF_RIGHTFOREARM_NODE 0x640
#define OFF_LEFTFOREARM_NODE  0x648
// Player data
#define OFF_PLAYERID        0x338
#define OFF_IPRIDATAPOOL    0x68
#define OFF_POOL_LIST       0x10
#define OFF_POOL_ITEM       0x20
#define OFF_POOL_VAL        0x18
// Aimbot
#define OFF_ROTATION        0x53C   // m_AimRotation
#define OFF_ROTATION2       0x172C  // m_CurrentAimRotation
// Attributes
#define OFF_PLAYER_ATTRS    0x680

// --- Functions ---
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

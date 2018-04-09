#ifndef _LADDER_H_
#define _LADDER_H_

#include "GoBoard.h"

// 全ての連に対して逃げて助かるシチョウかどうか確認
void LadderExtension( game_info_t *game, int color, bool *ladder_pos );

// シチョウ探索
bool IsLadderCaptured( int depth, game_info_t *game, int ren_xy, int turn_color );

// 戦術的特徴用の関数
bool CheckLadderExtension( game_info_t *game, int color, int pos );

#endif

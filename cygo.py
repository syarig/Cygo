
# TODO: Need type hintting and comment

AVAIL_PROC: int = 2
LAMBDA: float = 0.5
ROLLOUT_NUM: int = 6000

N_MOVES: int = 20
EXPAND_THR: int = 30
NODES_MAX: int = 10000

KOMI: float = 7.5
BOARD_SIZE: int = 19
MOVES_MAX: int = BOARD_SIZE ** 2 + 1

WIN_THR: float = 0.6
LOSE_THR: float = 0.2
RESIGN_CNT_THR: int = 3


def run_cygo(args):
    from apvmcts.gtp_handler import run_gtp
    from apvmcts.player import Cygo

    player = Cygo(args)
    run_gtp(player)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='Cygo is Go AI has feature of like AlphaGo Fan')

    parser.add_argument("--processes", "-p", default=AVAIL_PROC, type=int,
                        help=f"Number of available processes. Default: {AVAIL_PROC}")
    parser.add_argument("--lambda_val", "-l", default=LAMBDA, type=float,
                        help=f"Mixing parameter. Default: {LAMBDA}")
    parser.add_argument("--rollout", "-r", default=ROLLOUT_NUM, type=int,
                        help=f"Number of playout for tree searching. Default: {ROLLOUT_NUM}")
    parser.add_argument("--search-moves", "-m", default=N_MOVES, type=int,
                        help=f"Number of search moves for each nodes. Default: {N_MOVES}")
    parser.add_argument("--expand-thr", "-e", default=EXPAND_THR, type=int,
                        help=f"Number of node expanding threthold. Default: {EXPAND_THR}")
    parser.add_argument("--tree-size", "-t", default=NODES_MAX, type=int,
                        help=f"Tree size. Default: {NODES_MAX}")
    parser.add_argument("--komi", "-k", default=BOARD_SIZE, type=float,
                        help=f"Number of komi. Default: {KOMI}")
    parser.add_argument("--size", "-s", default=BOARD_SIZE, type=int,
                        help=f"Go board size. Default: {BOARD_SIZE}")
    parser.add_argument("--reuse-subtree", "-R", default=False, action="store_true",
                        help=f"Number of search moves for each nodes. Default: {N_MOVES}")
    parser.add_argument("--logging", "-g", default=False, action="store_true", help="debug mode")
    parser.add_argument("--verbose", "-v", default=False, action="store_true", help="debug mode")

    args = parser.parse_args()
    run_cygo(args)

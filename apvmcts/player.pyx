
import os, sys, time
import multiprocessing as mp
from multiprocessing.managers import BaseManager

import gtp
from alphago import go
from alphago.util import save_gamestate_to_sgf
from ray.wrapper import Ray, WHITE, BLACK
from apvmcts import tree
from apvmcts.gtp_handler import GtpPlayer
from apvmcts.search_worker import SearchWorker, conv_pos
from apvmcts.gpu_workers import PolicyWorker, ValueWorker
from util import get_graph_saver
from config import project_root, ray_dir, log_dir
sys.path.append(project_root)


DEBUG = True
WIN_THR = 0.6
LOSE_THR = 0.2
RESIGN_CNT_THR = 3


class MyManager(BaseManager):
    pass

MyManager.register('Tree', tree.Tree)
MyManager.register('Ray', Ray)
mm = MyManager()
mm.start()

pvque = mp.JoinableQueue()
rtque = mp.JoinableQueue(1)
procque = mp.JoinableQueue()

def conv_raycol(col):
    return WHITE if col == go.WHITE else BLACK

class Cygo(GtpPlayer):
    def __init__(self, cargs: object, gpuid0: int=0, gpuid1: int=1):
        self.b_resign_cnt = 0
        self.w_resign_cnt = 0
        self._lambda = cargs.lambda_val
        self._rollout = cargs.rollout
        self.expand_thr = cargs.expand_thr
        self.using_hash = cargs.reuse_subtree
        self.processes = cargs.processes
        self.state = go.GameState(cargs.size, cargs.komi, enforce_superko=True)

        self.moves_max = cargs.size ** 2 + 1
        self.apv_tree = mm.Tree(cargs.lambda_val, cargs.tree_size, self.moves_max)

        up_path = sp_path = ray_dir.encode('utf-8')
        self.ray = mm.Ray(up_path, sp_path)

        self.gjob0 = ValueWorker(gpuid0, self.apv_tree, pvque)
        self.gjob0.start()
        self.gjob1 = PolicyWorker(gpuid1, self.apv_tree, rtque,
                                  cargs.search_moves ,cargs.reuse_subtree)
        self.gjob1.start()

        loops = cargs.rollout // cargs.processes
        nlocks = [mp.Lock() for _ in range(cargs.tree_size)]
        elock = mp.Lock()

        self.jobs = [SearchWorker(
            self.apv_tree, pvque, rtque, procque,
            self.ray, tid, nlocks, elock,
            cargs.expand_thr, loops, cargs.reuse_subtree
        ) for tid in range(cargs.processes)]

        [job.start() for job in self.jobs]

        self.q_ary = self.r_ary = []
        self.save_graph = get_graph_saver(
            filename=os.path.join(log_dir, "evaluation.png"),
            title=f"$rollouts={self._rollout}$, $thr={self.expand_thr}$, $\lambda={self._lambda}$",
            xlabel="Moves", ylabel="Evaluation",
        )

    def clear(self):
        self.state = go.GameState(self.state.size, enforce_superko=True)
        self.apv_tree.clear()
        self.ray.gtp_clearboard()
        if len(self.q_ary) != 0 and len(self.r_ary) != 0:
            self.save_graph(Q=self.q_ary, R=self.r_ary)


    def make_move(self, col, vertex):
        # vertex in GTP language is 1-indexed, whereas GameState's are zero-indexed
        ray_col = conv_raycol(col)
        try:
            if vertex == gtp.RESIGN:
                return True

            (x, y) = vertex
            go_pos = conv_pos(vertex)
            self.state.do_move(go_pos, col)
            self.ray.put_stone(x, y, ray_col)

            return True
        except go.IllegalMove:
            return False

        except:
            import traceback
            traceback.print_exc()

    def set_size(self, n):
        self.state = go.GameState(n, enforce_superko=True)
        self.ray.gtp_boardsize(n)

    def set_komi(self, k):
        self.state.komi = k
        self.ray.set_komi(k)

    def get_current_state_as_sgf(self):
        from tempfile import NamedTemporaryFile
        temp_file = NamedTemporaryFile(delete=False)
        save_gamestate_to_sgf(self.state, '', temp_file.name)
        return temp_file.name

    def place_handicaps(self, vertices):
        actions = []
        for vertex in vertices:
            (x, y) = vertex
            actions.append((x - 1, y - 1))
        self.state.place_handicaps(actions)

    def select_best_move(self, col):

        self.gjob0.skip_off()

        ni = self.apv_tree.ready(self.state.get_current_hash()) \
            if self.using_hash else tree.NODE_NOT_FOUND

        if ni == tree.NODE_NOT_FOUND:
            kwargs = {'state': self.state,
                      'node_idx': tree.PARENT_OF_ROOT,
                      'child_idx': tree.PARENT_OF_ROOT}
            rtque.put(kwargs)
            rtque.join()
            ni = self.apv_tree.get_next_node_idx()
        else:
            print("{} root node has already expanded.".format(ni))

        for i in range(self.processes):
            procque.put((self.state, col, ni))
        procque.join()

        self.gjob0.skip_on()

        c = self.apv_tree.select_games(ni)

        pvque.join()

        if self.state.is_eye((c.x-1, c.y-1), col):
            return gtp.PASS, 0.0, 0.0

        return (c.x, c.y), c.Q, c.R

    def get_move(self, col):
        start = time.time()
        self.state.current_player = col
        ray_col = conv_raycol(col)

        if len(self.state.history) >= self.moves_max * 3:
            return gtp.PASS

        xy, q_val, r_val = self.select_best_move(ray_col)
        if ray_col == WHITE: r_val = self._lambda + r_val
        r_eval = r_val / self._lambda
        evaluation = q_val + r_val

        self.q_ary.append(q_val)
        self.r_ary.append(r_val)

        self.b_resign_cnt = self.b_resign_cnt + 1 \
            if r_eval < LOSE_THR and ray_col == BLACK else 0

        self.w_resign_cnt = self.w_resign_cnt + 1 \
            if r_eval < LOSE_THR and ray_col == WHITE else 0

        if len(self.state.history) > 1:
            if self.state.history[-1] is go.PASS and r_eval > WIN_THR:
                print("pass_threshold")
                return gtp.PASS
            if self.state.history[-1] is go.PASS and r_eval < LOSE_THR:
                print("pass_threshold")
                return gtp.PASS
            if self.b_resign_cnt > RESIGN_CNT_THR:
                print("resign_cnt=", self.b_resign_cnt)
                self.b_resign_cnt = 0
                return gtp.RESIGN
            if self.w_resign_cnt > RESIGN_CNT_THR:
                print("resign_cnt=", self.w_resign_cnt)
                self.w_resign_cnt = 0
                return gtp.RESIGN

        if DEBUG:
            self.state.print_board()
            elapsed_time = time.time() - start
            print("Evaluation: {:.8}\nQ: {:.8}, R: {:.8}\nelapsed time: {}".format(
                evaluation, q_val, r_val, elapsed_time))

        return xy

    def quit(self):
        mm.shutdown()
        self.gjob0.terminate()
        self.gjob1.terminate()
        [job.terminate() for job in self.jobs]
        sys.exit()


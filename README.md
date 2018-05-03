
# Cygoについて
AlphaGo Fanの論文を参考に作った囲碁AIです．AlphaGo Fanはプロを圧倒する棋力を示しましたが，ハードウェアに依存しており，ソースも公開されていません．
しかし，Cygoは少資源環境下で動作する囲碁AIを目指しました．探索アルゴリズムに幾つかの工夫を施しています．

１９路盤にのみ対応しており，同じプレイアウト数のときでは強豪のオープンソース囲碁プログラムであるRay， Fuego，Pachiよりも強いです．
ただし，実行速度が遅いためCythonを用いた高速化を進めています．


MacOSとUbuntu上で動作することを確認しています．おそらくWindows上でも動作するとは思いますが，動作確認はしてません．
ライセンスはGPLライセンスで，インターフェースは同梱していません．GoGuiなどのソフトを使って下さい．


# 環境構築
- [Keras](https://keras.io/ja/)を[TensorFlow](https://www.tensorflow.org/)バックエンドでインストール．
- `$ cd Cygo`で作業ディレクトリに移動
- 次のコマンドで依存しているライブラリをインストール．<br>
`$ pip install -r requirements.txt`

# コンパイル
Rayのラッパークラスや木構造の部分にCythonを使っているためコンパイルに下記のコマンドを実行します．`g++-6`でコンパイルするようになっています．環境に合わせて`setup.py`を変更して下さい．

`python setup.py build_ext -i`

Rollout policyをCythonで書いてみたのですが、高速動作を実現できなかったため代わりにRayのプレイアウトを使わせてもらってます．

# ネットワークの学習
`train_sl_policy.py, train_rl_policy.py, train_value_net.py`の３つのファイルに設定を記述して実行すると．
重みや，モデルなどのデータが`data/*`に作成されていきます．ディレクトリに関する設定は`config.py`から変更可能です．
各設定の詳細に関してはソースのコメントに書く予定です．

例）`python train_sl_policy_net.py`

|名称|用途|
---|---
|SL policy network|熟練者の着手予測|
|RL policy network|Value networkの訓練データの生成|
|Value network|盤面の評価|

# 実行
- `apvmcts/gpu_workers.py`の`SL_POLICY_NET_WEIGHT, VALUE_NET_WEIGHT`を使用したい重みのファイル名にする．
- `python cygo.py`を実行する．下記のような引数を取ることができます．
- PCのスペックに合わせて`--rollout`と`--tree-size`は調節して下さい．

```
usage: cygo.py [-h] [--processes PROCESSES] [--lambda_val LAMBDA_VAL]
               [--rollout ROLLOUT] [--search-moves SEARCH_MOVES]
               [--expand-thr EXPAND_THR] [--tree-size TREE_SIZE] [--komi KOMI]
               [--size SIZE] [--reuse-subtree] [--verbose]

Cygo is Go AI has feature of like AlphaGo Fan

optional arguments:
  -h, --help            show this help message and exit
  --processes PROCESSES, -p PROCESSES
                        Number of available processes. Default: 2
  --lambda_val LAMBDA_VAL, -l LAMBDA_VAL
                        Mixing parameter. Default: 0.5
  --rollout ROLLOUT, -r ROLLOUT
                        Number of playout for tree searching. Default: 6000
  --search-moves SEARCH_MOVES, -m SEARCH_MOVES
                        Number of search moves for each nodes. Default: 20
  --expand-thr EXPAND_THR, -e EXPAND_THR
                        Number of node expanding threthold. Default: 30
  --tree-size TREE_SIZE, -t TREE_SIZE
                        Tree size. Default: 10000
  --komi KOMI, -k KOMI  Number of komi. Default: 7.5
  --size SIZE, -s SIZE  Go board size. Default: 19
  --reuse-subtree, -R   Number of search moves for each nodes. Default: 20
  --verbose, -v         debug mode
```

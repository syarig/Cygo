
# Cygoについて
https://github.com/syarig/Cygo

AlphaGo Fanの論文を参考に作った囲碁AIです．AlphaGo Fanはプロを圧倒する棋力を示しましたが，ハードウェアに依存しており，ソースも公開されていません．
しかし，Cygoは少資源環境下で動作する囲碁AIを目指しました．探索アルゴリズムに幾つかの工夫を施しています．

１９路盤にのみ対応しており，同じプレイアウト数のときでは強豪のオープンソース囲碁プログラムであるRay， Fuego，Pachiよりも強いです．
ただし，実行速度が遅いためCythonを用いた高速化を進めています．


MacOSとUbuntu上で動作することを確認しています．おそらくWindows上でも動作するとは思いますが，動作確認はしてません．
ライセンスはGPLライセンスで，インターフェースは同梱していません．GoGuiなどのソフトを使って下さい．


# 環境構築
- 事前に`pipenv`を入れておいてください
- GPUを使うにはGPU版のtensorfowをインストールしてください
```shell
# Cygoをクローンしてくる
git clone https://github.com/syarig/Cygo.git
cd Cygo

# 必要なライブラリをインストール
pipenv install
```

# コンパイル
Rollout policyをCythonで書いてみたのですが、高速動作を実現できなかったため代わりにRayのプレイアウトを使わせてもらってます．
Rayのラッパークラスや木構造の部分にCythonを使っているためコンパイルに下記のコマンドを実行します。`g++5`以上をインストールしておいてください。

```shell
$ python setup.py build_ext -i
```


# ネットワークの学習
`train_sl_policy_net.py, train_rl_policy_net.py, train_value_net.py`のファイルを実行することでモデルを作成することができます。バッチ数等のパラメータもこのファイルに書いてあります。重みなど各種データは`data/*`に作成されます．ディレクトリに関する設定は`config.py`から変更してください。．

```shell
python train_sl_policy_net.py
```

|名称|用途|
---|---
|SL policy network|熟練者の着手予測|
|RL policy network|Value networkの訓練データの生成|
|Value network|盤面の評価|

# 実行
- `apvmcts/gpu_workers.py`の`SL_POLICY_NET_WEIGHT, VALUE_NET_WEIGHT`を使用したい重みのファイル名にする．
- `python cygo.py`を実行する．下記のような引数を取ることができます．
- PCのスペックに合わせて`--rollout`と`--tree-size`は調節して下さい．

例）`python cygo.py -t 1000 -r 1000 --logging --verbose`

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

# 対戦させてみる
このようにするとGoGuiとTwoGtpを使って対戦させることがでます。
パスやコマンド諸々はご自身の環境に合わして実行してください

```shell
#!/usr/bin/env bash
twogtp_cmd="gogui-twogtpのパス"
gogui_cmd="goguiのパス"
python_path="python環境へのパス"

ray="ray --no-debug --playout 6000"
pachi="pachi -d 0 -t =6000"
gnugo19="gnugo --mode gtp --level 15"
cygo="${python_path} cygo.pyへのパス"


BLACK=$ray
WHITE=$cygo

DIR="対戦結果の保存先"
FILE="対戦結果のファイル名"

TWOGTP="$twogtp_cmd \
  -black \"$BLACK\" -white \"$WHITE\" -games 50 \
  -size 19 -verbose -referee \"$gnugo\" -sgffile $DIR$FILE"

$gogui_cmd -size 19 -program "$TWOGTP" -computer-both -auto

$twogtp_cmd -analyze "${DIR}${FILE}.dat"
```


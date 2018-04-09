Installation
------------
1. 'cd' to the directory which includes 'Makefile'
2. Type 'make' to compile

How to run
----------
By default settings, Ray will consume 10 seconds each move on a single CPU 
and require 800MB of memory. 

    ./ray

Ray has some options :

Setting the total number of playouts per move (3000 PO/move). Default is 10000.

    ./ray --playout 3000

Ray plays with time settings 30:00 (1800 seconds).

    ./ray --time 1800       

Ray runs on 13x13. Default is 19x19 (Maximum is also 19x19).
You can ignore it if GTP sends 'boardsize' command.

    ./ray --size 13         
                  
Ray considers 5 seconds each move. 

    ./ray --const-time 5
    
Setting the number of threads. Default is 1 (Maximun is 32).

    ./ray --thread 4

Setting komi value. Default is 6.5.
You can ignore this command if GTP sends 'komi' command.

    ./ray --komi 7.5        
                  
Setting the number of handicap stones for test.
This makes Ray ignore komi command from GTP.

    ./ray --handicap 4      
                  
This makes Ray use subtree if it exist. Default is off.
This command saves Ray's remaining time.

    ./ray --reuse-subtree   
                  
This makes Ray think during the opponent's turn.
(Automatically, this command turns 'reuse-subtree mode' on)

    ./ray --pondering

Setting the number of uct nodes. Default is 16384. If you
want to run Ray with many threads and a long time setting,
I recommend you to use this command. The number of nodes must be 2^n.

    ./ray --tree-size

Ray never print Ray's log.

    ./ray --no-debug        

Ray avoids positional-superko move.

    ./ray --superko         


e.g.

Playing with 4 sec/move with 8 threads

    ./ray --const-time 4 --thread 8

Playing with 1000 playouts/move with 1 threads

    ./ray --playout 1000

Playing with 16 threads and 65536 uct nodes. Time setting is 30 minutes.
Ray thinks during the opponent's turn.

    ./ray --time 1800 --thread 16 --tree-size 65536 --pondering


License
-------
Ray is distributed under the BSD License.
Please see the "COPYING" file.

Contact
-------
rayauthor19x19@gmail.com (Yuki Kobayashi)

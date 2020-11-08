## 俄罗斯方块

### 开发环境



### 实现原理



### 难点和创新点



### 小组分工

#### 吴佳龙

+ 

#### 赵伊书杰

+ 

#### 黄舒炜

+ 



### 游戏介绍

俄罗斯方块，支持单机模式和多人乱斗模式。进入游戏后控制左右键和回车键选择游戏模式。

<img src="\pic\HomeSelect.png" alt="home select" style="zoom:40%;" />

#### 单机模式

+ 用户数量和服务器连接：单人，不需要连接服务器。

+ 界面显示：游戏框、下一个方块、游戏分数、道具种类和数量。

+ 游戏分数：消除一行、两行、三行和四行分别加10分、25分、50分、80分。

+ 方块下落速度：随着游戏分数增加，方块下落速度越来越快，达到最快速度后保持该速度。

+ 游戏操作：左右键控制方块移动，上键控制方块旋转，下键加速方块下落，123键使用相应道具，当一行填满自动消除，方块超出游戏框游戏结束。游戏道具：底部三行消失、减速、跳过下一个方块，一次性消除n行，赠送n-1个道具，道具种类依照一定概率随机，游戏初始赠送一个道具。

  <img src="\pic\SingleGame.png" alt="single game" style="zoom:25%;" /><img src="\pic\SingleGameOver.png" alt="single Game Over" style="zoom:25%;" />

#### 多人乱斗模式

+ 用户数量和服务器连接：1~4人，需要连接服务器。

+ 界面显示：游戏框、下一个方块、其他用户游戏界面、道具种类和数量。

+ 游戏道具：炸弹、异种方块、屏幕障碍，道具被使用对象为所有玩家中随机的一个玩家（包括自己），为其他用户增加苦难。一次性消除n行，赠送n-1个道具，道具种类依照一定概率随机，游戏初始赠送一个道具。

  <img src="\pic\beforeBomb.png" alt="beforeBomb" style="zoom:22%;" /><img src="\pic\AfterBomb.png" style="zoom:22%;" /><img src="\pic\special.png" alt="special" style="zoom:21%;" /><img src="\pic\Cover.png" alt="cover" style="zoom:21%;" />

  

  

+ 游戏操作：

  + 玩家需要根据游戏提示，输入ip地址，连接服务器。

    <img src="\pic\IpInput.png" alt="IpInput" style="zoom:20%;" /><img src="\pic\WaitConnect.png" style="zoom:20%;" /><img src="\pic\ConnectError.png" alt="ConnectError" style="zoom:20%;" />

  + 玩家连接成功后，需要根据游戏提示，准备开始游戏，当所有玩家准备完毕游戏自动开始。

    <img src="\pic\ReadyToPlay.png" alt="ReadyToPlay" style="zoom:25%;" /><img src="\pic\WaitOthers.png" style="zoom:25%;" />

  + 游戏操作与单人模式相似。方块超出游戏框该玩家游戏结束，根据游戏存活时间对所有玩家做出排名。

    <img src="\pic\MulGame.png" alt="MulGame" style="zoom:25%;" /><img src="\pic\MulGameOver.png" alt="MulGameOver" style="zoom:25%;" />
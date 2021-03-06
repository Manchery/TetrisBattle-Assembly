## 汇编实验报告：支持联机对战的俄罗斯方块

组长：吴佳龙 2018013418

组员：黄舒炜 2018013386, 赵伊书杰 2018013394 

### 开发环境与项目文件说明

#### 开发环境简述

- 集成开发环境：Visual Studio 2019
- 汇编器：MASM(32位)
- 操作系统：Windows 10
- 团队开发管理：Github, 石墨文档

#### 程序运行

- 运行/exe/server.exe，启动服务器。运行服务器前请确保端口10086未被占用。服务器的钟表图形仅供验证服务器没有阻塞用，无其它功能。
- 运行/exe/tetris.exe，启动游戏。游戏内可选择单人、多人模式。若以多人模式开始游戏，请先确保服务器已启动。在游戏内操作时，请关闭中文输入法或开启大写，否则程序无法响应键盘事件。

#### 项目文件结构

- /src/server是服务器端代码实现。server.sln是服务器端项目入口文件，可使用Visual Studio 2019及更高版本打开。
- /src/tetris是游戏端代码实现。tetris.sln是游戏端项目入口文件，可使用Visual Studio 2019及更高版本打开。
- 每个项目中，都以main.asm作为程序的入口。其余的文件都有必要的注释说明其作用，每个函数及重要变量也都有一定的注释说明其功能，因此可通过阅读源代码了解需要的详细信息。

### 实现原理

#### 基本架构

- 客户端

  我们将游戏在一帧中的事件分为“输入——逻辑——绘图”三部分分别处理。

  - 在输入部分，程序将会接收来自用户的键盘输入、并接收网络上从服务器端传来的指令。再按照要求将输入解析为便于程序使用的形式，供逻辑部分使用。
  - 在逻辑部分，程序将查看已有的输入，并根据上一帧保存的结果，计算这一帧内游戏主体的行为，再将这些修改保存到内存中，或通过网络发送到服务器端。
  - 在绘图部分，程序读取指定的变量，判断游戏当前的状态，再依次进行相应的绘图操作，从而将画面呈现给玩家。

- 服务器

  服务器以Windows消息机制驱动，一方面接收从客户端来的输入，并进行合适的响应或转发操作。另一方面服务器将维护所有玩家的游戏状态，并定期与每个玩家同步这些信息。 通信模型服务器端与客户端均采用非堵塞式套接字编程模型。利用Windows窗口消息机制，当新的网络事件（如读写、监听、连接、断开连接等）到来时，就向消息队列中加入一条对应的事件。而后再分别编写响应每个事件的函数即可。这种模型的好处是，网络通信与其它类型事件的行为（如用户I/O）对其它模块来说显得完全一致，这就降低了编程复杂度，同时提高了程序结构化的程度。 

- 游戏逻辑与绘图
  - 游戏的主要内容即为俄罗斯方块所对应的棋盘。因此，在游戏逻辑方面，通过维护一个二维数组（其实质仍为一段连续的内存区域），用数组中的每个元素代表游戏棋盘中的一个方块即可。而其余的内容（如游戏的道具、边界检测等）本质上也是对二维数组中的数值进行判断或修改，辅以其它的计算。这样，就完成了游戏逻辑的处理。
  - 在绘图方面，游戏采用GDI库提供的函数进行绘图操作。为了让绘制过程更加简洁和可靠，我们将游戏内的元素按照层级分类，如背景层、棋盘层、元素层等。再根据逻辑部分的计算结果判定需要哪些内容，依次将这些层级绘制到屏幕上即可。

### 小组分工

#### 吴佳龙

+ 前期绘图调研
+ 单机模式游戏逻辑和显示
+ 实现多人乱斗模式
+ 游戏逻辑和显示实现

#### 赵伊书杰

+ 前期网络通信调研
+ 客户端代码框架
+ 服务器端实现
+ 文档撰写

#### 黄舒炜

+ 前期游戏规则和通信指令设计
+ 游戏插图、背景图片绘制
+ 游戏页面逻辑跳转实现、代码调试
+ 文档撰写

### 游戏介绍

俄罗斯方块，支持单机模式和多人乱斗模式。进入游戏后控制左右键和回车键选择游戏模式。

<img src="\pic\HomeSelect.png" alt="home select" style="zoom:40%;" />

#### 单机模式

+ 用户数量和服务器连接：单人，不需要连接服务器。

+ 界面显示：游戏框、下一个方块、游戏分数、道具种类和数量。

+ 游戏分数：消除一行、两行、三行和四行分别加10分、25分、50分、80分。

+ 方块下落速度：随着游戏分数增加，方块下落速度越来越快，达到最快速度后保持该速度。

+ 游戏操作：左右键控制方块移动，上键控制方块旋转，下键加速方块下落，123键使用相应道具，当一行填满自动消除，方块超出游戏框游戏结束。游戏道具：底部三行消失、减速、跳过下一个方块，一次性消除n行，赠送n-1个道具，道具种类依照一定概率随机生成，游戏初始赠送一个道具。

  <img src="\pic\SingleGame.png" alt="single game" style="zoom:25%;" /><img src="\pic\SingleGameOver.png" alt="single Game Over" style="zoom:25%;" />

#### 多人乱斗模式

+ 用户数量和服务器连接：1~4人，需要连接服务器。

+ 界面显示：游戏框、下一个方块、其他用户游戏界面、道具种类和数量。

+ 游戏道具：炸弹、异种方块、屏幕障碍，道具被使用对象为所有玩家中随机的一个玩家（包括自己），为其他用户增加苦难。一次性消除n行，赠送n-1个道具，道具种类依照一定概率随机生成，游戏初始赠送一个道具。

  <img src="\pic\beforeBomb.png" alt="beforeBomb" style="zoom:22%;" /><img src="\pic\AfterBomb.png" style="zoom:22%;" /><img src="\pic\special.png" alt="special" style="zoom:21%;" /><img src="\pic\Cover.png" alt="cover" style="zoom:21%;" />

+ 游戏操作：

  + 玩家需要根据游戏提示，输入ip地址，连接服务器。

    <img src="\pic\IpInput.png" alt="IpInput" style="zoom:20%;" /><img src="\pic\WaitConnect.png" style="zoom:20%;" /><img src="\pic\ConnectError.png" alt="ConnectError" style="zoom:20%;" />

  + 玩家连接成功后，需要根据游戏提示，准备开始游戏，当所有玩家准备完毕游戏自动开始。

    <img src="\pic\ReadyToPlay.png" alt="ReadyToPlay" style="zoom:25%;" /><img src="\pic\WaitOthers.png" style="zoom:25%;" />

  + 游戏操作与单人模式相似。方块超出游戏框该玩家游戏结束，根据游戏存活时间对所有玩家做出排名。

    <img src="\pic\MulGame.png" alt="MulGame" style="zoom:25%;" /><img src="\pic\MulGameOver.png" alt="MulGameOver" style="zoom:25%;" />

### 难点和创新点

#### 难点与解决方案

- 汇编下服务器与客户端通信方案的设计

  由于网络也是游戏内输入的一部分，所以网络与游戏逻辑不可避免地需要交互。但是，网络上的事件通常不可预测（如何时到来输入、何时断开连接等）。如果直接让游戏逻辑直接操作套接字，就会需要处理过于复杂的情况，使代码变得臃肿。因此，我们对套接字进行了封装，向上提供简单的读写接口，使得游戏逻辑部分的开发与单机版基本一致。

- 由于本次实验采用汇编语言开发。因此，比起高级语言，游戏主体功能的实现将有更高的难度。我们使用了多种方式解决这个问题。比如，手动实现基本的数据结构操作函数，这样，就可以更加高效和方便地管理数据（特别是结构体）。又如，利用汇编语言的特性，改变通常的算法实现，从而简化了开发过程。比如对字符串和二维数组的处理就应用了直接对连续区域内存进行操作的方法。

#### 创新点

- 在传统的俄罗斯方块游戏的基础上添加联机模式，增加游戏互动性。联机模式需要客户端和服务器之间进行消息通信。
- 在单人模式和多人乱斗模式中添加不同的游戏道具，为游戏增加意外元素，增加游戏趣味性。
- 从计算机网络的设计中得到启发。让客户端参与尽量多的计算工作，而服务器只进行必要的计算，从而减轻了服务器的压力。
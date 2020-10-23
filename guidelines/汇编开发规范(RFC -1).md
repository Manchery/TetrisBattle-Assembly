### 汇编开发规范(RFC -1)

- 寄存器的使用：Callee**没有义务保存任何寄存器**，这就是说，在调用任何函数前，调用者必须将自己认为有用的寄存器显示push到栈中。

  *(TODO: 也许可以写两个宏，把所有寄存器都进行push/pop操作)*

- 调用规范：Callee在调用结束时，不能清除栈上不属于自己栈帧的任何数据（无论返回值是否保存在这部分区域中）。因此，**Caller必须自行清除存在栈上的参数（如果有且必须)**。

- 变量的命名规范：*TODO（wjl说全部使用全局变量，因此需要选择合适的命名方法）*

- 动态内存分配？*（让wjl确定）*

- 函数的定义：请务必使用注释写明**每一个函数**的用途（过于显然可以略去），传参形式（寄存器或栈上变量），传参作用，返回值的位置和格式。一个例子：

  ```assembly
  ;unsigned gcd(uint a, uint b)
  ;[Optional]returns the greatest common divisor of a & b, where a * b != 0
  ;Receives(Params, Input): eax <- a, [ebp + 8] <- b
  ;Returns(Output): eax <- gcd(a, b)
  ;[Optional]Error(Exception):
  ; edx == 0 if (a * b == 0)
  ```

- 数据格式的约定

  *TODO：如，只对字符串使用BYTE，只对整数使用DWORD？又如，只使用无符号整数（以避免意外的有符号和无符号比较）？*


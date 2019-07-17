# 贪吃蛇🍎🐍 

## 设计目标
实现经典的贪吃蛇游戏  
1. 果实随机生成
2. 吃到果实长度加1
3. 不能撞墙
4. 不能吃到自己
## 界面截图  
![window](./doc/window.PNG)  
## 设计思路
* 将分数、长度、果实坐标、蛇的各节点坐标都存放在数据段中  。
* 使用8086的显存地址打印画面，显存地址0xB8000-0xBFFFF共32KB的空间，为80\*25彩色字符模式的显示缓冲区，向这个地址空间写入数据，写入的内容立即出现在显示器上。
* 蛇的每一个节点的坐标在数据段snake偏移处，从snake处即是列、行、列、行的坐标对。
* 游戏开始后的逻辑流程如下面流程图所示：
```flow
st=>start: 开始游戏
c1=>condition: 缓冲区为空?
i1=>operation: 获取输入
c2=>condition: 是否反向
op1=>operation: 使用上次输入
op2=>operation: 使用本次输入
c3=>condition: 吃到果实?
op3=>operation: al设为1
op4=>operation: al设为0
io3=>operation: 画出蛇和果实
c4=>condition: al = 1?
op5=>operation: 增加节点，长度加1
op6=>operation: 更新蛇的每一个节点
c5=>condition: 是否撞墙
c6=>condition: 是否撞到自己
over=>end: 游戏结束
st->c1()
c1(no)->i1->c2()
c1(yes, right)->op1()
c2(yes,right)->op1()
c2(no)->op2()
op1->c3
op2->c3
c3(yes)->op3->io3
c3(no)->op4->io3
io3->c4
c4(no)->op6
c4(yes,right)->op5->op6->c5
c5(yes)->over
c5(no)->c6
c6(yes)->over
c6(no)->c1
```
## 重要功能的代码实现
### 异步输入
贪吃蛇游戏要求在任何时候进行输入都能够进行响应，而普通的同步输入中断若没有进行输入则会进入阻塞状态直到给出了键盘输入，所以我们在这里使用了INT 16H的1号功能来检查缓冲区，这个检查是异步的，会立即返回。
``` asm
; 若缓冲区有值，存入ax中，AH扫描码，AL中ASCII码
getInput: push bx
	  push ax
	  mov al, 0
	  mov ah, 1
	  int 16h  ; 检查缓冲区，非阻塞，非空则ZF=0，AL中存字符ASCII码，AH放键盘扫描码
	  cmp ah, 1
	  je getInputEnd
	  mov al, 0	
	  mov ah, 0
	  int 16h
	  pop bx
	  pop bx
	  jmp short getInputRet
getInputEnd: pop ax
	     pop bx
getInputRet: ret 
```
### 检测反向
在经典的贪吃蛇游戏中，若按下的键与贪吃蛇原本的前进方向相反，则此时蛇仍然按照原来的方向前进，列如本来蛇正向上方移动，此时按下↓键，蛇并不会向下运动。这个检测的流程如下：
1. 根据新输入的按键得到新的蛇头坐标
2. 将新的蛇头坐标和之前蛇身的第二个节点的坐标做比较
3. 若相同则表明发生反向，新的按键输入不可取，扔使用上一次的输入的方向
4. 若不同则表明没有发生反向，可以把新的按键输入作为新的方向

这里只取按下↑键时的判断作为代码例：
``` asm
dec dh
cmp dl, snake[2]
jne ok_to_turn
cmp dh, snake[3]
je not_ok_to_turn
jmp short ok_to_turn
```
### 蛇身更新
每一次蛇头移动后，蛇身都要进行更新。更新的算法非常简单：每一个节点的坐标都赋予其上一个节点的坐标值，如第二个节点赋予之前蛇头的坐标值，第三个节点赋予之前第二个节点的坐标值......如果吃到果实，在蛇尾补充一个节点即可。  
蛇身更新代码：
``` asm
; 长度不变
len_no_change: mov si, 0				; 蛇头
			mov bl, ds:[si+snake]
			mov bh, ds:[si+snake+1]
			cmp ah, 48h
			je moveup
			cmp ah, 50h
			je movedown
			cmp ah, 4bh
			je moveleft
			cmp ah, 4dh
			je moveright
			jmp short update_snake_ret

			; 调整蛇头
			moveup: dec byte ptr ds:[si+snake+1]		; 上移 (行 - 1)
				jmp short movebody
		      movedown:	inc byte ptr ds:[si+snake+1]	; 下移 (行 + 1)
				jmp short movebody
		      moveleft: dec byte ptr ds:[si+snake]		; 左移 (列 - 1)
				jmp short movebody
		     moveright:	inc byte ptr ds:[si+snake]		; 右移 (列 + 1)
				jmp short movebody

		      movebody: mov cx, len
				dec cx				
				jcxz update_snake_ret
				mov si, 2
				; 下一节点赋予上一节点的坐标
		        movelp: mov al, snake[si]   
				mov ah, snake[si+1]
				mov snake[si], bl
				mov snake[si+1], bh
				mov bx, ax
				add si, 2
				loop movelp
				jmp update_snake_ret				
		; 长度加1
	    len_change:	mov si, len
			mov di, si
			add di, si
			mov al, snake[di-2]
			mov ah, snake[di-1]  ; 最后一个节点坐标
			inc al               
			mov snake[di], al
			mov snake[di+1], ah  ; 新增加的节点
			inc si
			mov ds:[len], si	 ; 长度加1
			inc ds:[score]		 ; 分数加1		
			call refresh_fruit
			jmp len_no_change
```
### 碰撞检测
检测是否撞墙只需检测蛇头是否越界：
``` asm
    cmp byte ptr ds:[snake], 0				; collisions detect
    je gameover
    cmp byte ptr ds:[snake], 79
    je gameover
    cmp byte ptr ds:[snake+1], 2
    je gameover
    cmp byte ptr ds:[snake+1], 24
    je gameover
```
检测是否撞到自己要判断蛇头和每一个蛇身节点是否重合：
``` asm
self_collision: 
	cmp bl, ds:[si+snake]
	jne no_collision
	cmp bh, ds:[si+snake+1]
	je gameover
	no_collision:	
		add si, 2
	loop self_collision
```
### 其他模块  
还有有其他用于显示的模块，只不过是将内存中的坐标转换为8086的显存地址，再去设置相应ASCII字符和属性，在此不详述了。
***

## 中途遇到的问题
遇到的第一个问题是输入时的问题，一开始为了安全，在getInput模块把ax也push进去了然后在ret之前pop出来，结果怎么也得不到输入。很明显是因为ax永远都是调用getInput之前的值。总之这个错误很低级。

再是输入时的阻塞，开始时使用同步输入，这样程序会阻塞等待键盘输入，想让蛇移动只能一直按住方向键。改成缓冲区检查之后就可以只在变更方向时按下方向键了。

再一个问题是反向问题，一开始我并没有去判断反向，结果就是蛇运动的时候按与其运动方向相反的方向键，蛇即反向，蛇身坐标重合，实际上显示的蛇却变“短”了。后来增加了反向检测来解决这一问题。  


## 没有解决的问题

我的程序里我所能发现的bug基本上都解决了。有几个经典贪吃蛇里的功能并没有去实现。

经典的贪吃蛇是随着吃到的果实越多，蛇身边长且移动速度变快，我的程序并没有去设计移动速度的变化。还有障碍墙、不规则边界等一些拓展功能也没有实现。没有做的原因是时间所限还有其他的课程作业，难以面面俱到了。
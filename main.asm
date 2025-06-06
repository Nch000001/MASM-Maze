data segment ;定義迷宮大小

	MAZE_ROWS equ 23 ; 24*24 是 terminal 上限 
	MAZE_COLS equ 23 ; 但我怎麼處理 23 都會是他計算的上限 超過 23 之後 會印出至多到第24行 但實際地圖運算只到 23 行
	MAZE_SIZE equ MAZE_ROWS * MAZE_COLS ; 行*列 寫死 23*23

	; 想法是分成兩個地圖 實際地圖與玩家可視範圍

	mazeMap db MAZE_SIZE dup('#')  ; 實際地圖初始化為牆壁 方便DFS鑽路 註: dup =  將 數量 * dup(值) 填滿 mazeMap

	visibleMap db MAZE_SIZE dup('?') ; 可視地圖 初視化為全 '?' 在玩家可視範圍內再解鎖

	; 玩家座標
	playerX db 1 ; row
	playerY db 1 ; col : (0, 0) 是牆

	; 終點座標
	goalX db 2 ; row
	goalY db 2 ; col (23, 23)

	; 牆壁 = '#', 路 = '.', 不可視範圍 = '?', 玩家 = 'P', 終點 = 'O' 沒有為什麼 就是看起來很像一個洞.
	; 定義符號
	wall db '#'
	road db '.'
	fog db '?'
	player db 'P'
	goal db 'O'
	
	; 給 DFS 作使用的 STACK (用陣列模擬 方便操作 且可更改任意位置內容)
	stackX db 1024 dup(0);
	stackY db 1024 dup(0);
	pointer db 1 dup(1); 目前剩餘次數

	directionX db -1, 1, 0, 0 ; 定義四種方向 上下左右 (1, 0), (-1, 0), (0, -1), (0, 1)
	directionY db 0, 0, -1, 1 

	nextX db 1 ; PWN 的 N
	nextY db 1

	wallX db 1 ; PWN 的 W
	wallY db 1 

	shuffledX db 4 dup(0) ; 因 getrandomDir 遇到之問題 而增加的 shuffle 
	shuffledY db 4 dup(0)
	tempX     db 0
	tempY     db 0

	fogArr equ 9 ; 用於可視化地圖, 紀錄每次 player 移動後的可視位置
	fogSize equ 3 ; 設定迷霧大小 以正方形的邊長表示, 上面的 fodArr 則需是 fogSize^2, 最好是 '奇數' 這樣才有中心點

	; 最後是改變 輸出的顏色 讓 牆, 玩家, 路 有明顯區分, 不然眼睛好痛
    ; 根據 註3. 找到的 ANSI wiki 裡面說道 算了 寫在 report 裡面好了, 我繼續把註解當作文打, report 真的要沒東西用

    ; 先定義會使用到的顏色 
    ; labelName db "content", 結尾符號
	redWall db 27, "[31m", '$' ; 27寫在外面 因為我們需要保留他的 ASCII -> ESC , 31m 則是紅色的前景色代碼
    blueGoal db 27, "[1;34m", '$' ; 藍色看起來像傳送門, 跟 O 很搭
	resetColor db 27, "[0m", '$' ; 重設所有屬性用ESC[0m
	
data ends

stack segment stack ; 沒有用到內建的 stack, 會放這個純粹因為 不寫 stack segment 每次 run masm code 時 他會在 terminal 跳一行 warning 很煩
    dw 128 dup(?)
stack ends

; code 區段
code segment
	assume cs:code, ds:data, ss:stack
start:

	call init ; 初始化

	call makeMazeMap ; 製作地圖
	;call printMap ; 列印
    call waitKey
	mov ax, 4c00h
	int 21h

init PROC
	mov ax, data
	mov ds, ax
	ret
init ENDP

; 因為不使用recursive, 實際用陣列來模擬且操作, 大致演算法 => 
; 把玩家起始位置放進陣列 且 
; 執行LOOP直到陣列為空 : 1. 將位址取出, 2. 此位址尚未造訪則 = '.' (路) : 
; 3. 重複隨機選取一個方向: 假設 P W N  , P 為當前位置 WN皆為牆, 只要符合 N 為未造訪 且 W 為牆 兩個條件, 就將WN設為'路' 且 N 為下一次迴圈起點
; 4. 若該方向的下兩格皆為牆, 將中間的牆改為路 且 將第二格放進陣列 ;
makeMazeMap PROC

	; 把玩家起始位置放進陣列
    mov playerX, 1
    mov playerY, 1
    
    mov ax, 1
    mov bx, MAZE_COLS
    mul bx
    add ax, 1
    mov si, ax
    mov al, road
    mov mazeMap[si], al

	mov al, playerX
    mov stackX[0], al

    mov al, playerY
    mov stackY[0], al

    mov byte ptr [pointer], 1



	DFS:
		; 執行LOOP直到陣列為空
		mov al, [pointer]
		cmp al, 0
		je DFS_DONE

		;  1. 將位址取出
		dec pointer ; pointer -= 1
		mov bl, pointer ; 因為 pointer 是 db (1Byte) 需手動組合 bx 的高低半位 最後才能使用 bx (16bit register), (bh -> 0, bl -> pointer) = bx 
		mov bh, 0 

		mov al, stackX[bx] ; 取出下一個需處理的 x 
		mov playerX, al ; 放進 playerX

		mov al, stackY[bx] ; 同上述步驟
		mov playerY, al

		; ; 2. 此位址尚未造訪則 = '.' (路)
		; ; 若要得到 mazeMap[playerX][playerY] 的值, 因為是用陣列模擬, 所以把二維陣列用一維陣列的方式處理 => index = col_size * x + y
		; mov al, playerX
		; mov ah, 0 ; 手動分開操作高半位和低半位的理由和上述的 pointer 一致
		; mov bx, MAZE_COLS
		; mul bx ; ax = ax*bx 得到 col_size * x 
		
		; ; 接下來處理 + y
		; mov bl, playerY
		; mov bh, 0
		; add ax, bx ; ax = ax + bx
		; mov si, ax ; 放到 si 當索引 待會使用 mazeMap[si]

		; mov al, mazeMap[si]
		; cmp al, wall
		; jne DFS ; 比較如果 al 的內容不是牆 則代表以造訪過 跳過這輪
		
		; mov al, road
		; mov mazeMap[si], al ; 不允許 destination & source 同時為記憶體位址 所以要兩步操作, 先將路的內容放進al, 再將al放進地圖裡
		
		; 3. 隨機選取一個方向 用下方的 getRandomDirection 來實現
		; 拿到餘數表示第幾組 再從 directionX & Y [al] 中 來得到方向 從'方向'陣列內容->影響DFS要前進的方向
		; 應加上判斷是否為迷宮外牆 (如果本身要外面一圈必定為牆的話) 或者 在一開始就限制direc的活動範圍 只在 1 ~ size-2
		
		call shuffleDirection ; 再每次要選方向的時候, 先打亂 direction 裡 存放的方向順序, 不是每次都上下左右

		mov si, 0 ; 從 direction[0] 開始 ~ [3]

		newDirection:

			;call getRandomDirection

			; ; 回傳的放在al, 先將ah設成0 合併成 16bits -> ax 放進索引
			; mov ah, 0
			; mov si, ax

			cmp si, 4
			je DFS ; 代表所有方向都嘗試過
			
			; 因為 dircetion 裡面有 -1 的值 用一般的處理方式 當dir是負值時會有bug (親身體會)
			; cbw: Convert byte to word.								 from wiki -> x86 instruction listings
			; imul : Two-operand non-widening integer multiply.
			mov al, directionX[si] 
			cbw  
			mov bl, 2
			imul bl ; 根據上面的 PWN 例子 先將方向的位移量*2 得到 N 

			mov bl, playerX ; 再將另一個要素取出 相加之後 就是實際位移後的位置
			add al, bl 
			mov nextX, al ; 預移動的新位置, 放進next判斷位置是否合法
			
			mov al, directionY[si]
			cbw
			mov bl, 2
			imul bl ; 同 X 的操作
			
			mov bl, playerY
			add al, bl
			mov nextY, al ; y軸處理完畢->接下來判斷是不是在合法位置 不是就重來 (1 ~ size-2)

			; 因為 WN 的差距只有 位移量多1 但都是同個方向 所以只要 更前面的N合法 W 自然合法 -> 只檢查N合法與未造訪(牆) -> 再檢查 W 牆否
			mov al, nextX ; 用 next去檢查移動後的位置是否合法
			cmp al, 1 ; [0][y]
			jb skipDirection ; 不合法 -> 跳過這個方向
			cmp al, MAZE_ROWS - 2 ; [size-2][y]
			ja skipDirection

			mov al, nextY
			cmp al, 1 ; [x][0]
			jb skipDirection
			cmp al, MAZE_COLS - 2 ; [x][size-2]
			ja skipDirection
			
			; 經過上面測試代表 -> 接下來的位置合法, 檢查是不是牆, 用上面 2. 方法檢查 
			mov al, nextX
			mov ah, 0 ; 手動分開操作高半位和低半位的理由和上述的 pointer 一致
			mov bx, MAZE_COLS
			mul bx ; ax = ax*bx 得到 col_size * x 
			
			; 接下來處理 + y
			mov bl, nextY
			mov bh, 0
			add ax, bx ; ax = ax + bx
			mov bx, ax ; 移回 bx 當索引 待會使用 mazeMap[bx] 不跟 2. 一樣用 si 當索引的原因是 -> si 在 迴圈初始時 被用來存放 randomDirection 的回傳值, 之後也還需使用到 所以改用 bx 作為索引

			mov al, mazeMap[bx]
			cmp al, wall
			jne skipDirection ; 不是牆代表造訪過 下一輪

			; 確定 N 合法且牆 檢查 W
			mov al, directionX[si] ; 先把當前玩家加上位移放進 牆的位置
			mov bl, playerX
			add al, bl
			mov wallX, al

			mov al, directionY[si]
			mov bl, playerY
			add al, bl
			mov wallY, al ; (wallX, wallY) 為 W 的位置 -> 檢查是否為牆, 一樣根據 2. 的方法

			mov al, wallX
			mov ah, 0 ; 手動分開操作高半位和低半位的理由和上述的 pointer 一致
			mov bx, MAZE_COLS
			mul bx ; ax = ax*bx 得到 col_size * x 
			
			; 接下來處理 + y
			mov bl, wallY
			mov bh, 0
			add ax, bx ; ax = ax + bx
			mov bx, ax ; 移回 bx 當索引 待會使用 mazeMap[bx] 不跟 2. 一樣用 si 當索引的原因是 -> si 在 迴圈初始時 被用來存放 randomDirection 的回傳值, 之後也還需使用到 所以改用 bx 作為索引

			mov al, mazeMap[bx]
			cmp al, wall
			jne skipDirection ; W不是牆就不符合建立的原則 下一輪

			; 以上判斷完 把 W 打通 把 N 放進下一個執行位置
			mov al, road
			mov mazeMap[bx], al

            ; 再打通N
            mov al, nextX
            mov ah, 0
            mov bx, MAZE_COLS
            mul bx

            mov bl, nextY
            mov bh, 0
            add ax, bx
            
            mov bx, ax
            mov al, road
            mov mazeMap[bx], al

			; 把 nextX & Y 的位置給實際的 player 做下一次的移動
			mov al, nextX
			mov playerX, al
			mov bl, [pointer]
            mov bh, 0
			mov stackX[bx], al ; 放進stack 做下一輪操作

			mov al, nextY
			mov playerY, al
			mov stackY[bx], al

			; 加上 pointer 的次數 開啟下一次迴圈
			inc pointer
			jmp skipDirection

		skipDirection:

			inc si ; 為什麼不用 loop newDirection 而是 手動 --cx 然後 jnz:  error A2075: jump destination too far : by 60 byte(s) 
			jnz newDirection ; 因為寫太長 超過loop範圍了 XD

	DFS_DONE:

        mov playerX, 1
        mov playerY, 1
		mov al, playerX ; 設起點
		mov ah, 0
		mov bx, MAZE_COLS
		mul bx
		mov bl, playerY
		mov bh, 0

		add ax, bx
		mov si, ax
		mov al, player
		mov mazeMap[si], al

		mov al, goalX ; 終點
		mov ah, 0
		mov bx, MAZE_COLS
		mul bx
		mov bl, goalY
		mov bh, 0

		add ax, bx
		mov si, ax
		mov al, goal
		mov mazeMap[si], al

		ret
		
makeMazeMap ENDP

; 原本是給 隨機選擇方向用的 現在改拿來做洗牌器 總之回傳值是 0~3 放在 al
getRandomDirection PROC 

	mov ah, 2Ch ; 2CH = 獲取系統時間, CH = hour, CL = minute, DH = second, DL = hundredths
	int 21h

	mov al, dl ; 以秒數為種子
	mov ah, 0
	mov bl, 4 ; 取4的餘數 讓range落在[0, 3]
	div bl

	; 除法結果 =>  ax 除以 bl → 商在 al，餘數在 ah
	mov al, ah ; 將需要的結果移到 al
	ret

getRandomDirection ENDP

shuffleDirection PROC
	
	mov si, 3 ; 設一個也在 direction[X] 範圍內的值 

	shuffle:
		call getRandomDirection ; 原本是給 隨機選擇方向用的 現在改拿來做洗牌器 總之回傳值是 0~3 放在 al

		mov bl, al ; 回傳值併入 bx 當索引用
		mov bh, 0

		mov dx, 0
		mov ax, 0

		mov dl, directionX[si] ; 將 direciont[si] 跟 [al] 交換 al 是隨機來的值, 等等 si 再依次往下遞減
		mov al, directionX[bx]
		mov directionX[si], al
		mov directionX[bx], dl

		mov dl, directionY[si] ; 同 X 的操作
		mov al, directionY[bx] 
		mov directionY[si], al
		mov directionY[bx], dl

		dec si ; 遞減 si 做完回 DFS
		cmp si, 0
		jge shuffle
		ret

shuffleDirection ENDP

printMap PROC

	; 在每次執行列印地圖時 手動換一次行, 原因 : terminal 的輸出上限是 24, 但計算上限不知為何是 23 導致 如果想要遊戲正常 我只能讓地圖大小為 23*23
	; 但這樣每次在列印時 最上面一行會變成 上一次列印的地圖之最後一行, 於是在這邊手動換行, 土方解決
	mov ah, 02h
	mov dl, 0Dh
	int 21h
	mov dl, 0Ah
	int 21h
	; 根據 MAZE_ROWS * COLS, 每到基數就換行 用輸出字元的 逐個輸出

	; 用 cx 紀錄當前row, bx 紀錄 col -> ax要留著做乘法 , dx 中的 dl 會用來輸出 所以選 c & b

    ; 每次開始之前 1. 算出當前玩家位置的可視地圖, 2.改變可視地圖, 3.印出可視地圖
    
	mov cx, 0 ; 從0開始

	resetCol:
	
		; 檢查條件, row 到上限了沒
		cmp cx, MAZE_ROWS
		je endPrint

		mov bx, 0 ; 重置 col

	nextCol:
		
		; 同 2. -> 若要得到 mazeMap[playerX][playerY] 的值, 因為是用陣列模擬, 所以把二維陣列用一維陣列的方式處理 => index = col_size * x + y
		mov ax, cx
		mov dx, MAZE_COLS
		mul dx
		add ax, bx ; + y
		mov si, ax ; 把 最後的得到第幾位的數字放進 si 當索引

		mov al, visibleMap[si] ; 先偷看地圖內容, 判斷要用什麼顏色

		mov ah, wall ; 牆
		cmp ah, al
		je isWall

		mov ah, goal ; 終點
		cmp ah, al
		je isGoal

		lea dx, resetColor ; 不在可視範圍的內容 用預設的黑色, 才不會有提前被看光的問題
		mov ah, 09h
		int 21h
		jmp printChar

	isWall:
		lea dx, redWall
		mov ah, 09h
		int 21h
		jmp printChar

	isGoal:
		lea dx, blueGoal
		mov ah, 09h
		int 21h
		jmp printChar

	printChar:
		; 設定好顏色之後, 來這裡輸出
		
		mov dl, visibleMap[si] ; 印出當前位置的值
		mov ah, 02h
		int 21h
		
		inc bx ; y++
		cmp bx, MAZE_COLS  ; 比對到上限了沒
		jl nextCol
		jmp nextRow

	nextRow:

		; 換行 -> CR = 13 = 0D, LF = 10 = 0A
		mov ah, 02h
		mov dl, 0Dh
		int 21h
		mov dl, 0Ah
		int 21h

		inc cx ; x++
		jmp resetCol

	endPrint:
		ret

printMap ENDP

waitKey PROC
    
    waitKeyLoop:

		call calculateVisible
        call printMap

        mov ah, 07h ; 註 (2) 07h: 鍵盤輸入(無回顯) AL = 輸入字符
        int 21h
        
        cmp al, 57h ; W
        je pressW
		cmp al, 77h ; w
		je pressW
        cmp al, 41h ; A
        je pressA
		cmp al, 61h ; a
		je pressA
        cmp al, 53h ; S
		je pressS
		cmp al, 73h ; s
        je pressS
        cmp al, 44h ; D
		je pressD
		cmp al, 64h ; d
        je pressD
        jmp waitKeyLoop ; 按非法按鍵

        ; 在每一個輸入之後先檢查 X + 位移 & Y + 位移 會不會 = 牆 再考慮移動
        pressW: ; W (-1, 0)
            mov al, playerX
            dec al ; x--
            mov nextX, al ; 先放進 nextX -> 如果這位置可以用 最後要放進 playerX
            
            mov ah, 0
            mov bx, MAZE_COLS
            mul bx
            
            mov bl, playerY ; W = (-1, 0) 所以 Y 保持原本的就好 只有 X 需要用 nextX 來做嘗試
            mov bh, 0
            add ax, bx
            
            mov bx, ax ; bx = 下一步在陣列中的實際位置
            
            mov al, wall
            cmp mazeMap[bx], al
            je waitKeyLoop

            mov al, goal
            cmp mazeMap[bx], al
            je gameOver
            
            ; 非牆也非終點 -> 有路
            ; 先讓舊位置改成路, 然後 P 去新位置, 更新陣列 且 重畫地圖

            ; 計算舊位置

            mov cx, bx ; 先把算好的新位置存起來 再來算舊的

            mov al, playerX
            mov ah, 0
            mov bx, MAZE_COLS
            mul bx
            
            mov bl, playerY
            mov bh, 0
            
            add ax, bx
            mov bx, ax
            
            mov al, road ; 把舊位置改成牆
            mov mazeMap[bx], al

            ; 拿回剛剛存到 cx 的值
            mov bx, cx

            mov al, nextX ;  把 playerX 更新
            mov playerX, al

            mov al, player
            mov mazeMap[bx], al ; 改動地圖內的值
            jmp waitKeyLoop


        pressA: ; A (0, -1)
            mov al, playerX
			mov ah, 0
			
            mov bx, MAZE_COLS ; x * col_size
            mul bx
            
            mov bl, playerY ; A = (0, -1) , 'A' 是 移動 Y 所以要移到 nextY 預留等著改變 playerY
            mov bh, 0
			dec bl ; y--
			mov nextY, bl
			
            add ax, bx 
            
            mov bx, ax ; bx = 下一步在陣列中的實際位置
            
            mov al, wall
            cmp mazeMap[bx], al
            je waitKeyLoop

            mov al, goal
            cmp mazeMap[bx], al ; 其實往左應該不會有是終點的問題，終點預設寫在 (size-2, size-2) 不確定會不會改, 但會有死路的問題 (理論上)
            je gameOver
            
            ; 非牆也非終點 -> 有路
            ; 先讓舊位置改成路, 然後 P 去新位置, 更新陣列 且 重畫地圖

            ; 計算舊位置

            mov cx, bx ; 先把算好的新位置存起來 再來算舊的

            mov al, playerX
            mov ah, 0
            mov bx, MAZE_COLS
            mul bx
            
            mov bl, playerY
            mov bh, 0
            
            add ax, bx
            mov bx, ax
            
            mov al, road ; 把舊位置改成牆
            mov mazeMap[bx], al

            ; 拿回剛剛存到 cx 的值
            mov bx, cx

            mov al, nextY ;  把 playerY 更新
            mov playerY, al

            mov al, player
            mov mazeMap[bx], al ; 改動地圖內的值
            jmp waitKeyLoop
		
		pressS: ; S (1, 0)
            mov al, playerX
            inc al ; x++
            mov nextX, al ; 先放進 nextX -> 如果這位置可以用 最後要放進 playerX
            
            mov ah, 0
            mov bx, MAZE_COLS
            mul bx
            
            mov bl, playerY ; S = (1, 0) 所以 Y 保持原本的就好 只有 X 需要用 nextX 來做嘗試
            mov bh, 0
            add ax, bx
            
            mov bx, ax ; bx = 下一步在陣列中的實際位置
            
            mov al, wall
            cmp mazeMap[bx], al
            je waitKeyLoop

            mov al, goal
            cmp mazeMap[bx], al
            je gameOver
            
            ; 非牆也非終點 -> 有路
            ; 先讓舊位置改成路, 然後 P 去新位置, 更新陣列 且 重畫地圖

            ; 計算舊位置

            mov cx, bx ; 先把算好的新位置存起來 再來算舊的

            mov al, playerX
            mov ah, 0
            mov bx, MAZE_COLS
            mul bx
            
            mov bl, playerY
            mov bh, 0
            
            add ax, bx
            mov bx, ax
            
            mov al, road ; 把舊位置改成牆
            mov mazeMap[bx], al

            ; 拿回剛剛存到 cx 的值
            mov bx, cx

            mov al, nextX ;  把 playerX 更新
            mov playerX, al

            mov al, player
            mov mazeMap[bx], al ; 改動地圖內的值
            jmp waitKeyLoop
			
		pressD: ; D (0, 1)
            mov al, playerX
			mov ah, 0
			
            mov bx, MAZE_COLS ; x * col_size
            mul bx
            
            mov bl, playerY ; D = (0, 1) , 'D' 是 移動 Y 所以要移到 nextY 預留等著改變 playerY
            mov bh, 0
			inc bl ; y++
			mov nextY, bl
			
            add ax, bx 
            
            mov bx, ax ; bx = 下一步在陣列中的實際位置
            
            mov al, wall
            cmp mazeMap[bx], al
            je waitKeyLoop

            mov al, goal
            cmp mazeMap[bx], al ; 其實往左應該不會有是終點的問題，終點預設寫在 (size-2, size-2) 不確定會不會改, 但會有死路的問題 (理論上)
            je gameOver
            
            ; 非牆也非終點 -> 有路
            ; 先讓舊位置改成路, 然後 P 去新位置, 更新陣列 且 重畫地圖

            ; 計算舊位置

            mov cx, bx ; 先把算好的新位置存起來 再來算舊的

            mov al, playerX
            mov ah, 0
            mov bx, MAZE_COLS
            mul bx
            
            mov bl, playerY
            mov bh, 0
            
            add ax, bx
            mov bx, ax
            
            mov al, road ; 把舊位置改成牆
            mov mazeMap[bx], al

            ; 拿回剛剛存到 cx 的值
            mov bx, cx

            mov al, nextY ;  把 playerY 更新
            mov playerY, al

            mov al, player
            mov mazeMap[bx], al ; 改動地圖內的值
            jmp waitKeyLoop

        gameOver:
            ret
waitKey ENDP

; 用於每次移動前計算的玩家當前位置可視範圍 (已經看過的區域則會恆亮 -> 降低遊戲難度)
calculateVisible PROC

	; 流程 -> 計算 index = playerX * col_size + y 先得到位置 再依序放進 減一個(col_size + 1) 得到左上角 以此類推

	;	0	1	2
	;	3	P	5
	;	6	7	8

	mov al, playerX
	mov ah, 0
	mov bx, MAZE_COLS
	mul bx ; ax = x * col_size
	
	mov bl, playerY
	mov bh, 0
	
	add ax, bx ; 加上 y 的位移量
	mov cx, ax ; 移到 cx 備用 (玩家當前位置)

    ; 將基準點放在 bx 上 根據 -1, +1 位移量來得到他左邊跟右邊的 3P5 中的 3 和 5

	; 再來是拿出 mazpMap[index] 中 實際的值 覆蓋在 visible 中 直接改變可視地圖 -> 就可以完成 已經看過的區域則保持恆亮, 未探索的區域則依舊是 '?' 的實作

	mov di, fogSize ; 讀取設定的迷霧大小
	; 因 在定義時提到的 fogSize 最好設定為奇數, 那可以 用 (總邊長 - 1) / 2  來找到需要上下位移的位移量.
	; Ex. 如果是邊長是 3 , 玩家的可視範圍應是 自身為中心的 3*3 九塊格子, 以自身為基準 上下皆須偏移 1 邊長.

	dec di ; di -= 1
    ; DIV : (1) AX = DX:AX / r/m; resulting DX = remainder. (2) AL = AX / r/m; resulting AH = remainder
    ; 根據 DIV 定義 (2) 得到 AL = AX / r/m; 表示 div r/m 是讓 AL/ (r/m) 而不是 我將除數寫入 al 當分母用
    ; 所以要先把需要被除的資料 (fogSize) 移到 al -> mov di = 2 再做除法, 且 al 為商 , ah 為餘 這樣的話應該是不用先減, 直接做除法也可以, 為了避免報錯還是有自己手動操作就是了

    mov ax, di ; ax 原本是 3P5中的 3 借放到 dx, ax要拿去做除法
    mov di, 2
    
    div di ; al = fogSize / 2 
    
    ; 因為 di 是 16 bit 要移上去之前 先把 ah (餘數) 清空, 放 商 進去就好
    mov ah, 0
    mov di, ax ; 把最後得到的商拿回來 以 fogSize = 3 為例子, 這裡應該是 1 得到所需的偏移量
	
    ; 我在想的方法是 di = 1 , 我把他存起來 做 +/-(di) , dec di -> di = 0 再做 di = 0. 每次執行完一圈 就 dec di until 0 (要在proc 尾巴判斷 不然 0 不會處理)
    ; 這樣當 di = 2, 3 以上 應該都能一樣處理

	fogLoop:
		
        mov dx, di ; 把 剩下的偏移量移至 dx
        
        mov ax, MAZE_COLS ; 準備算出當前單位偏移量的位移, 拿 colSize 做乘法
        mul dx ; ax = ax*dx 

		; register - register :  SUB 在 wiki 中的 定義 (1) : r -= r/m/imm;
		; 先幫 cx 當前位置 做備份
		mov bx, cx ; bx = cx 備份
		;用 bx 根據偏移量改變地圖

		sub bx, ax ; 當前位置 - 偏移量

		mov si, bx
		dec si
        mov al, mazeMap[si] ; si = bx - 1 做的跟前面的註解說的一樣
		mov visibleMap[si], al
		
		inc si
		mov al, mazeMap[si]
		mov visibleMap[si], al

		inc si
		mov al, mazeMap[si]
		mov visibleMap[si], al

        cmp di, 0 ; 先判斷這輪是不是 0 了 代表 0 處理完畢了 不是的話 接著 -- 處理下一輪
        jl endLoop
		dec di
        jmp fogLoop

		endLoop:
			ret
	

		; 這段的結論 : 原本多加一個 fogSize 的初衷, 是為了之後的擴展性, 可讓玩家自定義迷霧大小或者根據遊戲難度調整, 但因應 MASM 的輸出上限 只有 23*23
		; 如果還能調整迷霧大小, 會讓遊戲變得太容易, 也算替我節省一點時間了. 
		; 這也是這段沒有加上 visibleMap 地圖改變之合法性判斷, 因為只能看到3*3的情況下, 且 地圖在建立之初 就將 最外圍一圈設定為牆. 導致不管怎麼樣 都不可能改變超出 visibleMap 陣列範圍的東西.

calculateVisible ENDP


code ends
; code區段結束
end start ; 從start開始


; 以下是第一版的列印地圖 意在 印出整張地圖 (全看的到), 主要做 -> 地圖算法和位移確認用. 
; printMap PROC
; 	; 根據 MAZE_ROWS * COLS, 每到基數就換行 用輸出字元的 逐個輸出

; 	; 用 cx 紀錄當前row, bx 紀錄 col -> ax要留著做乘法 , dx 中的 dl 會用來輸出 所以選 c & b

; 	mov cx, 0 ; 從0開始

; 	resetCol:
	
; 		; 檢查條件, row 到上限了沒
; 		cmp cx, MAZE_ROWS
; 		je endPrint

; 		mov bx, 0 ; 重置 col

; 	nextCol:
		
; 		; 同 2. -> 若要得到 mazeMap[playerX][playerY] 的值, 因為是用陣列模擬, 所以把二維陣列用一維陣列的方式處理 => index = col_size * x + y
; 		mov ax, cx
; 		mov dx, MAZE_COLS
; 		mul dx
; 		add ax, bx ; + y
; 		mov si, ax ; 把 最後的得到第幾位的數字放進 si 當索引

; 		mov dl, mazeMap[si] ; 印出當前位置的值
; 		mov ah, 02h
; 		int 21h
		
; 		inc bx ; y++
; 		cmp bx, MAZE_COLS  ; 比對到上限了沒
; 		jl nextCol
; 		jmp nextRow

; 	nextRow:

; 		; 換行 -> CR = 13 = 0D, LF = 10 = 0A
; 		mov ah, 02h
; 		mov dl, 0Dh
; 		int 21h
; 		mov dl, 0Ah
; 		int 21h

; 		inc cx ; x++
; 		jmp resetCol

; 	endPrint:
; 		ret

; printMap ENDP
data segment ;定義迷宮大小

	MAZE_ROWS equ 30
	MAZE_COLS equ 30
	MAZE_SIZE equ MAZE_ROWS * MAZE_COLS ; 行*列 寫死 30*30

	; 想法是分成兩個地圖 實際地圖與玩家可視範圍

	mazeMap db MAZE_SIZE dup('#')  ; 實際地圖初始化為牆壁 方便DFS鑽路 註: dup =  將 數量 * dup(值) 填滿 mazeMap

	visibleMap db MAZE_SIZE dup('?') ; 可視地圖 初視化為全 '?' 在玩家可視範圍內再解鎖

	; 玩家座標
	playerX db 1 ; row
	playerY db 1 ; col : (0, 0) 是牆

	; 終點座標
	goalX db 28 ; row
	goalY db 28 ; col (28, 28)

	; 牆壁 = '#', 路 = '.', 不可視範圍 = '?', 玩家 = 'P', 終點 = 'O' 沒有為什麼 就是看起來很像一個洞.
	; 定義符號
	wall db '#'
	road db '.'
	fog db '?'
	player db 'P'
	goal db 'O'

	; 給 DFS 作使用的 STACK (用陣列模擬 方便操作 且可更改任意位置內容)
	stackX db 100 dup(0);
	stackY db 100 dup(0);
	pointer db 0

	directionX db 1, -1, 0, 0 ; 定義四種方向 上下左右 (1, 0), (-1, 0), (0, -1), (0, 1)
	directionY db 0, 0, -1, 1

data ends

; code 區段
code segment
	assume cs:code, ds:data
start:

	call init ; 初始化

	mov ax, 4c00h
	int 21h

init PROC
	mov ax, data
	mov ds, ax
	ret
init ENDP

; 因為不使用recursive, 實際用陣列來模擬且操作, 大致演算法 => 
; 把玩家起始位置放進陣列 且 
; 執行LOOP直到陣列為空 : 1. 將位址取出, 2. 此位址尚未造訪則 = '.' (路)
; 3. 隨機選取一個方向, 4. 若該方向的下兩格皆為牆, 將中間的牆改為路 且 將第二格放進陣列 ;
makeMazeMap PROC

	; 把玩家起始位置放進陣列
	mov al, playerX
	mov stackX[0], al
	
	mov al, playerY
	mov stackY[0], al

	mov pointer, 1

	
	DFS:

		; 執行LOOP直到陣列為空
		mov al, pointer
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

		; 2. 此位址尚未造訪則 = '.' (路)
		; 若要得到 mazeMap[playerX][playerY] 的值, 因為是用陣列模擬, 所以把二維陣列用一維陣列的方式處理 => index = row_size * x + y
		mov al, playerX
		mov ah, 0 ; 手動分開操作高半位和低半位的理由和上述的 pointer 一致
		mov bx, MAZE_ROWS
		mul bx ; ax = ax*bx 得到 row_size * x 
		
		; 接下來處理 + y
		mov bl, playerY
		mov bh, 0
		add ax, bx ; ax = ax + bx
		mov si, ax ; 放到 si 當索引 待會使用 mazeMap[si]

		mov al, mazeMap[si]
		cmp al, wall
		jne DFS ; 比較如果 al 的內容不是牆 則代表以造訪過 跳過這輪
		
		mov al, road
		mov mazeMap[si], al ; 不允許 destination & source 同時為記憶體位址 所以要兩步操作, 先將路的內容放進al, 再將al放進地圖裡
		
		; 應加上判斷是否為迷宮外牆 (如果本身要外面一圈必定為牆的話) 或者 在一開始就限制direc的活動範圍 只在 1 ~ size-2 
		

		; 3. 隨機選取一個方向 用下方的 getRandomDirection 來實現
		; 拿到餘數表示第幾組 再從 directionX & Y [al] 中 來得到方向 從'方向'陣列內容->影響DFS要前進的方向
		call getRandomDirection
	
	
	
	DFS_DONE:
		ret
		
makeMazeMap ENDP

; 為DFS取得隨機方向
getRandomDirection PROC

	mov ah, 2Ch ; 2CH = 獲取系統時間, CH = hour, CL = minute, DH = second, DL = hundredths
	int 21h

	mov ah, dh ; 以秒數為種子

	mov bl, 4 ; 取4的餘數 讓range落在[0, 3]
	div bl

	; 除法結果 =>  ax 除以 bl → 商在 al，餘數在 ah
	mov al, ah ; 將需要的結果移到 al
	ret

getRandomDirection ENDP

code ends
; code區段結束
end start ; 從start開始
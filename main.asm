.386
.MODEL FLAT, STDCALL
OPTION CASEMAP:NONE

INCLUDE C:\masm32\include\windows.inc
INCLUDE    C:\masm32\include\user32.inc
INCLUDE    C:\masm32\include\kernel32.inc
INCLUDE    C:\masm32\include\gdi32.inc
INCLUDELIB C:\masm32\lib\user32.lib
INCLUDELIB C:\masm32\lib\kernel32.lib
INCLUDELIB C:\masm32\lib\gdi32.lib

WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD

;zainicjowane dane

.DATA

	ClassName DB "CalculatorWindow",0   ;nazwa naszej klasy okna
	AppName   DB "ASM CALC",0 			;tytuł naszego okna

	;######################PRZYCISKI###################################
	BtnClass DB "Button", 0
	Btn1Text DB "1", 0
	Btn2Text DB "2", 0
	Btn3Text DB "3", 0
	Btn4Text DB "4", 0
	Btn5Text DB "5", 0
	Btn6Text DB "6", 0
	Btn7Text DB "7", 0
	Btn8Text DB "8", 0
	Btn9Text DB "9", 0
	Btn0Text DB "0", 0
	BtnMulText DB "*", 0
	BtnDivText DB "/", 0
	BtnPlusText DB "+", 0
	BtnMinusText DB "-", 0
	BtnEqualText DB "=", 0
	BtnClearText DB "C", 0

	Label1 DB "NUM1", 0
	LabelSig DB " ", 0
	Label2 DB "NUM2", 0

	MsgResultTitle DB "RESULT", 0
	MsgBuffNumOverflowTitle DB "WARNING: NUMBER BIT", 0
	MsgBuffNumOverflowN1 DB "Bit 4, please select operation + - * / or C", 0
	MsgBuffNumOverflowN2 DB "Bit 4, please select operation + - * / if you want change or =  C", 0
	MsgDig0Title DB "WARNING: INVALID FORMAT", 0
	LineString DB "_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _", 0
	ZeroDiv DB "Can not div by 0", 0
	GUI_LAST_RESULT_TEXT DB "LAST RESULT", 0

	Result DD 0

	CurrentNumber DD 0				;ktora liczbe wczytujemy
	Num1 DD 0
	Num2 DD 0
	
	BuffNumMax = 4
	BuffNum1 DD BuffNumMax DUP (0) 	;zapisuje w ASCII cyfry 1 liczby
	BuffNum2 DD BuffNumMax DUP (0) 	;dzapisuje w ASCII cyfry 2 liczby
	BuffNum1Elements DD 0
	BuffNum2Elements DD 0
	
	BuffResultMax = 16
	BuffResult DD BuffResultMax DUP (0) ;sluzy do wyswietlenia wyniku w MSGBox
	BuffTemp DD BuffResultMax DUP (0) 	;sluzy do odwrocenia wyniku
	BuffTempElements DD 0

	DD10 DD 10

;niezainicjowane dane

.DATA?

	hInstance   HINSTANCE ?              ;uchwyt egzemplarza naszego programu
	CommandLine LPSTR ?                  ;wskazanie wiersza poleceń
	hwndBtn HWND ? 						 ;uchwyte przycisku

.CONST
	Btn1ID equ 1
	Btn2ID equ 2
	Btn3ID equ 3
	Btn4ID equ 4
	Btn5ID equ 5
	Btn6ID equ 6
	Btn7ID equ 7
	Btn8ID equ 8
	Btn9ID equ 9
	Btn0ID equ 0
	BtnMulID equ 10
	BtnDivID equ 11
	BtnPlusID equ 12
	BtnMinusID equ 13
	BtnEqualID equ 14
	BtnClearID equ 15
	D10 equ 10

;tutaj rozpoczyna się nasz kod

.CODE

	start:
		INVOKE GetModuleHandle, NULL    ;pobieramy uchwyt programu
		mov    hInstance, eax           ;pod Win32 hmodule==hinstance
		INVOKE GetCommandLine           ;pobierz wiersz polecenia. Nie musisz wywoływać
		mov    CommandLine, eax         ;tej funkcji, jeśli twój program nie przetwarza
										;wiersza polecenia
		INVOKE WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT ;główna funkcja
		INVOKE ExitProcess, eax         ;kończymy program. Kod wyjścia jest zwracany w eax z WinMain.

		WinMain PROC hInst: HINSTANCE, hPrevInst: HINSTANCE, CmdLine: LPSTR, CmdShow: DWORD

		LOCAL wc:   WNDCLASSEX               ;na stosie tworzymy zmienne lokalne
		LOCAL msg:  MSG
		LOCAL hwnd: HWND
											 ;wypełniamy pola struktury wc
			mov    wc.cbSize, SIZEOF WNDCLASSEX
			mov    wc.style, CS_HREDRAW or CS_VREDRAW
			mov    wc.lpfnWndProc, OFFSET WndProc
			mov    wc.cbClsExtra, NULL
			mov    wc.cbWndExtra, NULL
			push   hInstance
			pop    wc.hInstance
			mov    wc.hbrBackground, COLOR_WINDOW+1
			mov    wc.lpszMenuName, NULL
			mov    wc.lpszClassName, OFFSET ClassName
			INVOKE LoadIcon, NULL, IDI_SHIELD
			mov    wc.hIcon, eax
			mov    wc.hIconSm, eax
			INVOKE LoadCursor,NULL, IDC_ARROW
			mov    wc.hCursor, eax
			INVOKE RegisterClassEx, ADDR wc   ;rejestrujemy naszą klasę okna
			INVOKE CreateWindowEx,	NULL,
									ADDR ClassName,
									ADDR AppName,
									WS_OVERLAPPEDWINDOW and not WS_MAXIMIZEBOX and not WS_SIZEBOX,
									CW_USEDEFAULT,
									CW_USEDEFAULT,
									312,					;szerokosc okna
									480,					;wysokosc okna
									NULL,
									NULL, hInst, NULL
			mov    hwnd, eax
			INVOKE ShowWindow, hwnd, CmdShow  ;wyświetlamy nasze okno na pulpicie
			INVOKE UpdateWindow, hwnd         ;odświeżamy obszar roboczy

			.WHILE TRUE                       ;wchodzimy w pętle wiadomości
				INVOKE GetMessage, ADDR msg, NULL, 0, 0
				.BREAK .IF (!eax)
				INVOKE TranslateMessage, ADDR msg
				INVOKE DispatchMessage, ADDR msg
			.ENDW

			mov eax, msg.wParam               ;kod powrotu zwracamy w eax
			ret

		WinMain ENDP

		;###################################################################
		;int main()
		;###################################################################

		WndProc PROC hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM

		;###################################################################
		;zmienne lokalne, przy kazdej aktualizacji
		;gui sa od nowa inicjalizowane
		LOCAL hdc:  HDC						 ;potrzebne aby namalowac tekst
		LOCAL ps:   PAINTSTRUCT
		LOCAL rect: RECT
		;###################################################################
			.IF uMsg==WM_DESTROY             ;jeśli użytkownik zamyka okno

				INVOKE PostQuitMessage,NULL  ;kończymy pracę aplikacji

			; APP_GUI
			.ELSEIF uMsg==WM_CREATE

				; row 1
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR BtnEqualText, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				1, 400, 75, 50, hWnd, BtnEqualID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn0Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				77, 400, 75, 50, hWnd, Btn0ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR BtnClearText, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				154, 400, 75, 50, hWnd, BtnClearID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR BtnDivText, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				230, 400, 75, 50, hWnd, BtnDivID, hInstance, 0
				; row 2
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn1Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				1, 349, 75, 50, hWnd, Btn1ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn2Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				77, 349, 75, 50, hWnd, Btn2ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn3Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				154, 349, 75, 50, hWnd, Btn3ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR BtnMulText, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				230, 349, 75, 50, hWnd, BtnMulID, hInstance, 0
				; row 3
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn4Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				1, 298, 75, 50, hWnd, Btn4ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn5Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				77, 298, 75, 50, hWnd, Btn5ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn6Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				154, 298, 75, 50, hWnd, Btn6ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR BtnMinusText, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				230, 298, 75, 50, hWnd, BtnMinusID, hInstance, 0
				;row 4
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn7Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				1, 247, 75, 50, hWnd, Btn7ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn8Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				77, 247, 75, 50, hWnd, Btn8ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR Btn9Text, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				154, 247, 75, 50, hWnd, Btn9ID, hInstance, 0
				INVOKE CreateWindowEx, 0, ADDR BtnClass, ADDR BtnPlusText, \
				WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
				230, 247, 75, 50, hWnd, BtnPlusID, hInstance, 0

				mov BuffResult[0], 48
				mov BuffResult[1], 0
				mov BuffNum1[0], 48
				mov BuffNum1[1], 0
				mov BuffNum2[0], 48
				mov BuffNum2[1], 0

			; APP_CONTROLLER
			.ELSEIF uMsg == WM_COMMAND

				.IF wParam >= 0

					.IF wParam == 0

						.IF CurrentNumber == 0
							.IF BuffNum1Elements == 0
								jmp DIG_TYPE_ERR_BREAK
							.ENDIF
							jmp NO_ZERO_FIRST
						.ELSEIF
							.IF BuffNum2Elements == 0
								jmp DIG_TYPE_ERR_BREAK
							.ENDIF
							jmp NO_ZERO_FIRST
						.ENDIF

					.ENDIF

					.IF wParam <= 9 ;przyciski cyfr
						NO_ZERO_FIRST:
						xor eax, eax
						xor edx, edx
						mov ebx, BuffNumMax

						.IF CurrentNumber == 0

							.IF BuffNum1Elements == ebx
								INVOKE MessageBox, hWnd, ADDR MsgBuffNumOverflowN1, OFFSET MsgBuffNumOverflowTitle, MB_OK
								JMP DIG_TYPE_ERR_BREAK
							.ENDIF
							
							mov edi, OFFSET BuffNum1
							mov eax, 48 ; znak 0 ASCI
							add eax, wParam
							mov ecx, BuffNum1Elements
							mov dword ptr [edi+ecx], eax ;dodaje czyt. zapisuje  znak do BuffNum1
							add ecx, 1 ;inkrementacja licznika BuffNum1Index
							mov BuffNum1Elements, ecx
						.ELSE

							.IF BuffNum2Elements == ebx
								INVOKE MessageBox, hWnd, ADDR MsgBuffNumOverflowN2, OFFSET MsgBuffNumOverflowTitle, MB_OK
								JMP DIG_TYPE_ERR_BREAK
							.ENDIF
							
							mov eax, 48 ; znak 0 ASCI
							add eax, wParam
							mov ecx, BuffNum2Elements
							mov BuffNum2[ecx], eax ;dodaje czyt. zapisuje  znak do BuffNum1
							add ecx, 1 ;inkrementacja licznika BuffNum1Index
							mov BuffNum2Elements, ecx

						.ENDIF

						DIG_TYPE_ERR_BREAK:
					.ELSEIF wParam <= 13 ;przyciski do wykonywania dzialan

						;Btn mul
						.IF wParam == 10
							mov LabelSig, "*"
						;Btn div
						.ELSEIF wParam == 11
							mov LabelSig, "/"
						;Btn plus
						.ELSEIF wParam == 12
							mov LabelSig, "+"
						;Btn minus
						.ELSE
							mov LabelSig, "-"
						.ENDIF

						;zabezpieczenie aby nie dalo sie za szybko przejsc na 2 liczbe
						.IF BuffNum1Elements > 0
							mov CurrentNumber, 1 ;ustawienie na druga liczbe
							mov DD10, 1 ;"zerowanie" licznika mnozenia
						.ENDIF

					.ELSE ;przyciski specjalne

						;Btn equal
						.IF wParam == 14

							.IF LabelSig != " "
								GO_TO_EQUAL:

								.IF BuffNum1Elements < 1
									mov Num1, 0
								.ELSE
									mov esi, offset BuffNum1 	;zrodlowy offset
									push BuffNum1Elements		;ilosc elementow buffora
									call _StringToIntBuff
									mov Num1, eax
								.ENDIF

								.IF BuffNum2Elements < 1
									mov Num2, 0
								.ELSE
									mov esi, offset BuffNum2 	;zrodlowy offset
									push BuffNum2Elements		;ilosc elementow buffora
									call _StringToIntBuff
									mov Num2, eax
								.ENDIF

								.IF LabelSig == "+"
									mov eax, Num1 
									add eax, Num2
									mov Result, eax
								.ELSEIF LabelSig == "-"
									mov eax, Num1 
									sub eax, Num2
									mov Result, eax
								.ELSEIF LabelSig == "*"
									xor edx, edx
									mov eax, Num1 
									mov ebx, Num2
									mul ebx
									mov Result, eax
								.ELSEIF Num2 > 0
									xor edx, edx
									mov eax, Num1 
									mov ebx, Num2
									div ebx
									mov Result, eax
								.ELSE
									INVOKE MessageBox, hWnd, ADDR ZeroDiv, OFFSET MsgDig0Title, MB_OK
									jmp CLEAR_VALUES_OPTION
								.ENDIF

								;zamiana INT na STRING
								mov edi, offset BuffResult	;docelowy offset stringa	
								push Result
								call _IntToStringBuff
								INVOKE MessageBox, hWnd, ADDR BuffResult, OFFSET MsgResultTitle, MB_OK
								
								jmp CLEAR_VALUES_OPTION
								
							.ENDIF

						;Btn clear
						.ELSE
							CLEAR_VALUES_OPTION:
							mov LabelSig, " "
							mov CurrentNumber, 0
							mov Result, 0
							;mov BuffResult[0], 0
							mov BuffNum1[0], 48
							mov BuffNum1[1], 0
							mov BuffNum2[0], 48
							mov BuffNum2[1], 0
							mov BuffTemp[0], 0
							mov BuffNum1Elements, 0
							mov BuffNum2Elements, 0
							mov BuffTempElements, 0
							mov Num1, 0
							mov Num2, 0
							mov DD10, 1
						.ENDIF

					.ENDIF

					INVOKE InvalidateRect, hWnd, NULL, TRUE; odswierzenie tekstu na ekranie

				.ENDIF

			; APP_PRINT_TEXT
			.ELSEIF uMsg==WM_PAINT

				INVOKE BeginPaint, hWnd, ADDR ps
				mov    hdc, eax
				INVOKE GetClientRect, hWnd, ADDR rect

				INVOKE TextOut, hdc, 50, 25, ADDR Label1, 4
				INVOKE TextOut, hdc, 150, 25, ADDR LabelSig, 1
				INVOKE TextOut, hdc, 210, 25, ADDR Label2, 4

				mov eax, BuffNumMax
				INVOKE TextOut, hdc, 50, 50, ADDR BuffNum1, eax
				INVOKE TextOut, hdc, 150, 50, ADDR LabelSig, 1
				mov eax, BuffNumMax
				INVOKE TextOut, hdc, 210, 50, ADDR BuffNum2, eax

				INVOKE TextOut, hdc, 50, 75, ADDR LineString, 33
				
				INVOKE TextOut, hdc, 110, 185, ADDR GUI_LAST_RESULT_TEXT, 11
			    INVOKE DrawText, hdc, ADDR BuffResult, -1, ADDR rect,\
          			   DT_SINGLELINE or DT_CENTER or DT_VCENTER

				INVOKE EndPaint, hWnd, ADDR ps

			.ELSE
				INVOKE DefWindowProc, hWnd, uMsg, wParam, lParam ;standardowa obsługa okna
				ret
			.ENDIF

			XOR eax, eax
			ret

		WndProc ENDP

	_IntToStringBuff PROC NUM: DWORD
		;EDI - BUFFOR DOCELOWY
		mov eax, NUM
		mov ecx, 0					
		ConvertNextIntToChar:
			xor edx, edx 					;bez tego wyrzuca wyjatek
			mov ebx, D10 					;10 do ebx
			div ebx 						;akumulator / 10 - reszta w EDX
			add edx, 48 					;cyfra w ASCII
			mov BuffTemp[ecx], edx 			;zapisuje je tymczasowo - w odwrotnej kolejnosci
			inc ecx 						;zwiekszam indeks tablicy
			cmp eax, 0 						;jesli zero to konczymy petle
			jnz ConvertNextIntToChar
		mov BuffTempElements, ecx
		call _ReverseBuff
		ret
	_IntToStringBuff ENDP

	_ReverseBuff PROC 
		;EDI - BUFFOR DOCELOWY
		mov esi, offset BuffTemp			;ladujemy offset SOURCE
		mov ecx, BuffTempElements			;ladujemy ilosc elementow w tablicy
		dec ecx								;dekrementujemy aby otrzymac ostatni indeks tablicy		
		add esi, ecx						;ESI wskazuje ostatni element w SOURCE
		inc ecx								;licznik							
	SwapNextChars:	
		mov eax, [esi]						;do EAX laduje ostatnia cyfre
		mov dword ptr [edi], eax			;dodaje ja na koniec DESTINATION
		mov dword ptr [esi], 0				;"usuwamy" ostatni element SOURCE
		dec ecx								;zmniejszamy ilosc elementow
		jz SwitchBuffEsiEdi
		dec esi								;przechodze na nowy koniec SOURCE
		inc edi								;przechodze do kolejnej komorki DESTINATION	
	jmp SwapNextChars				
	SwitchBuffEsiEdi:
	 	inc edi
		mov dword ptr [edi], 0				;dodanie znaku konca lini	
	ret
	_ReverseBuff ENDP

	_StringToIntBuff PROC LENG: DWORD
		;ESI - OFFSET BUFFORA
		mov ecx, LENG
		mov edi, 0					;zapisujemy tu wynik (zamiast od razu do Num1)
		mov ebx, 1					;mnoznik
		dec ecx						;dekrementujemy aby otrzymac ostatni indeks tablicy
		add esi, ecx				;przechodze do ostatniego elementu
	ConvertNextChar:
		mov eax, [esi]				;do EAX laduje ostatnia cyfre
		sub eax, 48					;ASCII -> INT
		mul ebx						;cyfra * potega 10
		add edi, eax				;dodaje do zapamietanej liczby
		mov eax, 0					;laduje znak konca lini
		mov dword ptr [esi], eax	;"usuwam" ostatni element lancucha
		dec ecx						;zmniejszam ilosc elementow
		cmp ecx, -1					;sprawdzenie czy mamy jeszcze jakis element
		jz Converted
		dec esi					    ;wstecz do nastepnego elementu 
									;aktualizacja mnoznika
		mov eax, ebx
		mov ebx, D10
		mul ebx
		mov ebx, eax
		jmp ConvertNextChar
	Converted:
		mov eax, edi                ;zwracanie liczby
		ret
	_StringToIntBuff ENDP

	END start
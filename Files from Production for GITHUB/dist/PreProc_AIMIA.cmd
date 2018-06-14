rem prepare Files: Variable $TRM_TPLT replacement
D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 8.0\dist\outputs"

set wdir=%CD%
 
SET SYSTM=%TIME%
SET SYSHH=%SYSTM:~0,2%
SET SYSMI=%SYSTM:~3,2%
SET SYSSS=%SYSTM:~6,2%
SET CURRTM=%SYSHH%%SYSMI%%SYSSS%

rem pad timestamp if the first char is emtpy
if "%CURRTM:~0,1%"==" " SET CURRTM=0%CURRTM:~1,5%
 
 ::==============================Written by Rob van der Woude=============================
:: Keep variables local
SETLOCAL ENABLEDELAYEDEXPANSION

:: Query the registry for the date format and delimiter
CALL :DateFormat

:: Parse today's date depending on registry's local date format settings
IF %iDate%==0 FOR /F "TOKENS=1-4* DELIMS=%sDate%" %%A IN ('DATE/T') DO (
	SET LocalFormat=MM%sDate%DD%sDate%YYYY
	SET tLocal=%%tMonth%%%sDate%%%tDay%%%sDate%%%tYear%%
	SET yLocal=%%yMonth%%%sDate%%%yDay%%%sDate%%%yYear%%
	SET Year=%%C
	SET Month=%%A
	SET Day=%%B
)
IF %iDate%==1 FOR /F "TOKENS=1-4* DELIMS=%sDate%" %%A IN ('DATE/T') DO (
	SET LocalFormat=DD%sDate%MM%sDate%YYYY
	SET tLocal=%%tDay%%%sDate%%%tMonth%%%sDate%%%tYear%%
	SET yLocal=%%yDay%%%sDate%%%yMonth%%%sDate%%%yYear%%
	SET Year=%%C
	SET Month=%%B
	SET Day=%%A
)
IF %iDate%==2 FOR /F "TOKENS=1-4* DELIMS=%sDate%" %%A IN ('DATE/T') DO (
	SET LocalFormat=YYYY%sDate%MM%sDate%DD
	SET tLocal=%%tYear%%%sDate%%%tMonth%%%sDate%%%tDay%%
	SET yLocal=%%yYear%%%sDate%%%yMonth%%%sDate%%%yDay%%
	SET Year=%%A
	SET Month=%%B
	SET Day=%%C
)

:: Remove the day of week if applicable
FOR %%A IN (%Year%)  DO SET Year=%%A
FOR %%A IN (%Month%) DO SET Month=%%A
FOR %%A IN (%Day%)   DO SET Day=%%A

:: Today's date in MMDDYYYY format
SET SortDate=%Month%%Day%%Year%

:: Remove leading zeroes
IF   "%Day:~0,1%"=="0" SET   Day=%Day:~1%
IF "%Month:~0,1%"=="0" SET Month=%Month:~1%

:: Calculate yesterday's date
CALL :JDate %Year% %Month% %Day%
SET /A JDate -= 1
CALL :GDate %JDate%
FOR /F "tokens=1-3" %%A IN ('ECHO %GDate%') DO (
	SET yYear=%%A
	SET yMonth=%%B
	SET yDay=%%C
)


:: Add leading zero to tDay, yDay, tMonth and/or yMonth if necessary
IF 1%tDay%   LSS 20 SET tDay=0%tDay%
IF 1%yDay%   LSS 20 SET yDay=0%yDay%
IF 1%tMonth% LSS 20 SET tMonth=0%tMonth%
IF 1%yMonth% LSS 20 SET yMonth=0%yMonth%

:: Yesterday's in MMDDYYYY format
SET SortYest=%yMonth%%yDay%%yYear%


::==================== Header Record for all files ====================
>HeaderRow%TRM_TPLT%.txt echo 0,Segments,DS,20,%SortDate%,%CURRTM%,0,%SortYest%,1231%Year%

::==================== begin: Loop through files ====================
FOR /F "usebackq delims=" %%i IN ("%TRM_MANIFEST_FILE%") DO (
	::for /f %%a in ('type "%%i"^|find "" /v /c') do set /a cnt=%%a+2
	for /f %%a in ('Find /V /C "" ^< %%i') do (
        set /a cnt=%%a+2
    )
	::==================== Trailer Record for the current file ====================
	>TrailerRow%TRM_TPLT%.txt echo 9,Segments,DS,20,%SortDate%,%CURRTM%,!cnt!
	
	copy /B "HeaderRow%TRM_TPLT%.txt" + "%%i" = newfile%TRM_TPLT%.txt
	copy /B "newfile%TRM_TPLT%.txt" + "TrailerRow%TRM_TPLT%.txt" = newfile2%TRM_TPLT%.txt
    copy /B /Y newfile2%TRM_TPLT%.txt "%%i"
    del "newfile%TRM_TPLT%.txt"
	del "newfile2%TRM_TPLT%.txt"
    del "HeaderRow%TRM_TPLT%.txt"
	del "TrailerRow%TRM_TPLT%.txt"
)
::==================== end: Loop through files ====================


ENDLOCAL&SET Yesterday=%SortYest%&SET Today=%SortDate%& SET CurTime=%CURRTM%

GOTO:EOF

:: * * * * * * * *  Subroutines  * * * * * * * *


:DateFormat
REG.EXE /? 2>&1 | FIND "REG QUERY" >NUL
IF ERRORLEVEL 1 (
	CALL :DateFormatRegEdit
) ELSE (
	CALL :DateFormatReg
)
GOTO:EOF


:DateFormatReg
FOR /F "tokens=1-3" %%A IN ('REG Query "HKCU\Control Panel\International" ^| FINDSTR /R /C:"[is]Date"') DO (
	IF "%%~A"=="REG_SZ" (
		SET %%~B=%%~C
	) ELSE (
		SET %%~A=%%~C
	)
)
GOTO:EOF


:DateFormatRegEdit
:: Export registry's date format settings to a temporary file, in case REG.EXE is not available
START /W REGEDIT /E %TEMP%.\_TEMP.REG "HKEY_CURRENT_USER\Control Panel\International"
:: Read the exported data
FOR /F "tokens=1* delims==" %%A IN ('TYPE %TEMP%.\_TEMP.REG ^| FIND /I "iDate"') DO SET iDate=%%B
FOR /F "tokens=1* delims==" %%A IN ('TYPE %TEMP%.\_TEMP.REG ^| FIND /I "sDate"') DO SET sDate=%%B
DEL %TEMP%.\_TEMP.REG
:: Remove quotes from exported values
SET iDate=%iDate:"=%
SET sDate=%sDate:"=%
GOTO:EOF


:GDate
:: Convert Julian date back to "normal" Gregorian date
:: Argument : Julian date
:: Returns  : YYYY MM DD
::
:: Algorithm based on Fliegel-Van Flandern
:: algorithm from the Astronomical Almanac,
:: provided by Doctor Fenton on the Math Forum
:: (http://mathforum.org/library/drmath/view/51907.html),
:: and converted to batch code by Ron Bakowski.
::
SET /A P      = %1 + 68569
SET /A Q      = 4 * %P% / 146097
SET /A R      = %P% - ( 146097 * %Q% +3 ) / 4
SET /A S      = 4000 * ( %R% + 1 ) / 1461001
SET /A T      = %R% - 1461 * %S% / 4 + 31
SET /A U      = 80 * %T% / 2447
SET /A V      = %U% / 11
SET /A GYear  = 100 * ( %Q% - 49 ) + %S% + %V%
SET /A GMonth = %U% + 2 - 12 * %V%
SET /A GDay   = %T% - 2447 * %U% / 80
:: Clean up the mess
FOR %%A IN (P Q R S T U V) DO SET %%A=
:: Add leading zeroes
IF 1%GMonth% LSS 20 SET GMonth=0%GMonth%
IF 1%GDay%   LSS 20 SET GDay=0%GDay%
:: Return value
SET GDate=%GYear% %GMonth% %GDay%
GOTO:EOF


:JDate
:: Convert date to Julian
:: Arguments : YYYY MM DD
:: Returns   : Julian date
::	
:: Algorithm based on Fliegel-Van Flandern
:: algorithm from the Astronomical Almanac,
:: provided by Doctor Fenton on the Math Forum
:: (http://mathforum.org/library/drmath/view/51907.html),
:: and converted to batch code by Ron Bakowski.
::
SET /A Month1 = ( %2 - 14 ) / 12
SET /A Year1  = %1 + 4800
SET /A JDate  = 1461 * ( %Year1% + %Month1% ) / 4 + 367 * ( %2 - 2 -12 * %Month1% ) / 12 - ( 3 * ( ( %Year1% + %Month1% + 100 ) / 100 ) ) / 4 + %3 - 32075
FOR %%A IN (Month1 Year1) DO SET %%A=
GOTO:EOF
::==============================Written by Rob van der Woude=============================
 


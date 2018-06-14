REM ****************************************************************
REM  Command File to add timestap and send email notification, emails are added as a parameter
REM  Usage: "D:\Program Files\Apache Software Foundation\Tomcat 7.0\dist\PostProc_AddTimeStampNotification_param.cmd" "email1@teradata.com email2@pg.com" 
REM  Updated: May/12/2014, PS186001, TD
REM  Script is based on PostProc_AddTimeStampNotification.cmd
REM
REM *****************************************************************                                                                  
 
SETLOCAL ENABLEDELAYEDEXPANSION                                                                                                                                         
                                             
rem prepare Files: Variable $TRM_TPLT replacement
D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 8.0\dist"
set wdir=%CD%
 
SET SYSTM=%TIME%
SET SYSHH=%SYSTM:~0,2%
SET SYSMI=%SYSTM:~3,2%
SET SYSSS=%SYSTM:~6,2%
SET CURRTM=%SYSHH%%SYSMI%%SYSSS%
SET "DTM=%DATE:~5,10%_%TIME%"

rem pad timestamp if the first char is emtpy
if "%CURRTM:~0,1%"==" " SET CURRTM=0%CURRTM:~1,5%

FOR /F "usebackq delims=" %%i IN ("%TRM_MANIFEST_FILE%") DO (
  echo off
  find /v "" "%%i" > ~Temp%TRM_TPLT%%CURRTM%.txt      
  echo on

   set jfile=%%~ni
   echo %jfile%

   set file=%%~ni%CURRTM%.txt
   echo %file%

  echo off
  for /f "tokens=1,* delims=[]" %%a in (~Temp%TRM_TPLT%%CURRTM%.txt) do set Last=%%a
   type "%%i" | find /v "%Last%" > newfile%TRM_TPLT%%CURRTM%.txt
  
   echo Deleting ~Temp%TRM_TPLT%%CURRTM%.txt
   del /Q ~Temp%TRM_TPLT%%CURRTM%.txt

   echo Deleting "%%i"
   del /Q "%%i" 

   for /f %%C in ('Find /V /C "" ^< "newfile%TRM_TPLT%%CURRTM%.txt"') do set /A nRows=%%C
   echo Rows:"!nRows!"

   if /i "!nRows!" == "1" GOTO EMPTYFILE	
   
	:FULLFILE
        set Empty=0
	echo Full file
	copy /B "newfile%TRM_TPLT%%CURRTM%.txt" "\\%%~pi%%~ni%CURRTM%.txt"
	GOTO DELANDNOTIFY


	:EMPTYFILE
	set Empty=1
	echo Empty File
	copy /B "newfile%TRM_TPLT%%CURRTM%.txt" "D:\EmptyFiles\%file%" 

 	
	:DELANDNOTIFY
	del /Q newfile%TRM_TPLT%%CURRTM%.txt
	
	echo Communication Id: %TRM_COM%
	echo Empty: %Empty%
	echo File: %jfile%


rem EmptyFileIndicator: %EmptyFile%
rem Sender : PROD.Relationship.Builder@Teradata.com
rem FileName: %jfile%
rem Posted Time Stamp:v
rem CommunicationId: %TRM_COM%
rem Submit USer: %TRM_USER%
rem Alternate email:PM230127@Teradata.com
rem Epsilon Recipients : IC-PG-APAC-1CP@epsilon.com IC-PG-NA-1CP@epsilon.com

 java -cp TrmSendNotif.jar com.trm.mailer.TrmSendNotification %Empty% PROD.Relationship.Builder@Teradata.com %jfile% %CURRTM% %TRM_COM% %TRM_USER% thong.tran@Teradata.com %~1

)

exit 0
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

REM SET $PATH="D:\Program Files\Java\jre7\bin"
SET $PATH="D:\Program Files\Java\jre7\bin"

FOR /F "usebackq delims=" %%i IN ("%TRM_MANIFEST_FILE%") DO (
   echo off
   find /v "" "%%i" > ~Temp%TRM_TPLT%%CURRTM%.txt      
   for /f "tokens=1,* delims=[]" %%a in (~Temp%TRM_TPLT%%CURRTM%.txt) do set Last=%%a
   type "%%i" | find /v "%Last%" > newfile%TRM_TPLT%%CURRTM%.txt
   echo on
   copy /B newfile%TRM_TPLT%%CURRTM%.txt "\\%%~pi%%~ni%CURRTM%.txt"
   del /Q ~Temp%TRM_TPLT%%CURRTM%.txt
   del /Q newfile%TRM_TPLT%%CURRTM%.txt
   del /Q "%%i"


rem Mail Server : com.trm.test.TrmSendNotification
rem Sender : PROD.Relationship.Builder@Teradata.com
rem FileName : "%%~ni%CURRTM%.txt"
rem TrmUser: yr250002
rem Alternate email:PM230127@Teradata.com
rem Recipients : IC-PG-APAC-1CP@epsilon.com IC-PG-NA-1CP@epsilon.com
rem SMTP Port : 25
rem Recipient Number: 2

java -cp TrmSendNotif.jar com.trm.mailer.TrmSendNotification smtp.ushrnd4.savvis.net PROD.Relationship.Builder@Teradata.com "%%~ni%CURRTM%.txt" %TRM_USER% PM230127@Teradata.com IC-PG-APAC-1CP@epsilon.com IC-PG-NA-1CP@epsilon.com IC-PG-EMEA-1CP@epsilon.com 25 4)

exit 0
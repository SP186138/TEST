rem prepare Files: Variable $TRM_TPLT replacement
D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 7.0\dist"
set wdir=%CD%
 
SET SYSTM=%TIME%
SET SYSHH=%SYSTM:~0,2%
SET SYSMI=%SYSTM:~3,2%
SET SYSSS=%SYSTM:~6,2%
SET CURRTM=%SYSHH%%SYSMI%%SYSSS%
SET "DTM=%DATE:~5,10%_%TIME%"

rem Temporary file containing trm user name from search and replace $USER
SET GetMailTmp1=.\EmailNotificationLog\%TRM_USER%_%TRM_RUN%_GetMailSql1.tmp

rem Temporary file 2 containing final sql file from search and replace file location and file name
SET GetMailTmp2=.\EmailNotificationLog\%TRM_USER%_%TRM_RUN%_GetMailSql2.tmp

rem Define GetMail sql log file
SET GetMailLog=.\EmailNotificationLog\%TRM_USER%_%TRM_RUN%_BteqGetMailSql.log

rem Temporary file containing user email address
SET MailAddress=.\EmailNotificationLog\%TRM_USER%_%TRM_RUN%_EmailAddress.tmp


rem pad timestamp if the first char is emtpy
if "%CURRTM:~0,1%"==" " SET CURRTM=0%CURRTM:~1,5%

SET $PATH="D:\Program Files\Java\jre7\bin"

ssr.exe 0 $USER %TRM_USER% getMail.sql %GetMailTmp1%

sleep.exe 1

ssr.exe 0 $MailAddress %MailAddress% %GetMailTmp1% %GetMailTmp2%

sleep.exe 1

rem email save in File

bteq < %GetMailTmp2% > %GetMailLog%

sleep.exe 2


for /f "delims=" %%x in (%MailAddress%) do set USERMAIL=%%x

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
rem Recipients : IC-PG-APAC-1CP@epsilon.com IC-PG-NA-1CP@epsilon.com
rem SMTP Port : 25
rem Recipient Number: 2

java -cp TRMMailer.jar;mail-1.4.jar com.trm.mailer.TrmSendNotification smtp.ushrnd4.savvis.net PROD1.Relationship.Builder@Teradata.com "%%~ni%CURRTM%.txt" %USERMAIL% 25 1)
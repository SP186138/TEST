rem prepare Files: Variable $TRM_TPLT replacement
D:
cd "D:\Program Files\Apache Software Foundation\Tomcat 8.0\dist"
set wdir=%CD%
 

SET SYSTM=%TIME%
SET SYSHH=%SYSTM:~0,2%
SET SYSMI=%SYSTM:~3,2%
SET SYSSS=%SYSTM:~6,2%
SET CURRTM=%SYSHH%%SYSMI%%SYSSS%
rem if %CURRTM:~0,1%<>'1' (
rem   SET CURRTM=0%CURRTM:~1,3%
rem )
	
ssr.exe 0 $TRM_TPLT %TRM_TPLT% addHeader.sql addHeader.tmp

rem Header Row save in File
bteq < addHeader.tmp > HeaderRow.log

rem Files concatenate
FOR /F "usebackq delims=" %%i IN ("%TRM_MANIFEST_FILE%") DO (
    copy "Headerrow%TRM_TPLT%.tmp" + "%%i" newfile.txt

    DEL  /Q "%%i"
)

.RUN FILE=D:\Program Files\Apache Software Foundation\Tomcat 7.0\dist\outputs\logon.sql

.SET WIDTH 1500;
.SET TITLEDASHES OFF;
.SET SIDETITLES OFF;

--------------------------------------------------------------------------------------------------
-- Deleting the file that contains the Header Row                                               --
--------------------------------------------------------------------------------------------------
.OS if exist "$MailAddress" (del "$MailAddress")

--------------------------------------------------------------------------------------------------
-- Export the result of the SQL, which is the Header Row, to a flat file                        --
--------------------------------------------------------------------------------------------------
.EXPORT FILE="$MailAddress"
DATABASE TRM_META_DB;
SEL EMAIL FROM CR_USER WHERE USER_NAME='$USER';

.EXPORT RESET;

.LOGOFF;

.QUIT;

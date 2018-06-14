:begin
REM *********************************************************
REM  Intraday Batch Resubmit Rule command file
REM  Executes PE Client call to submit next run of Intraday Batch
REM  Initial Build 05/03/2013 … Ken Theall Teradata
REM *********************************************************
@echo off
echo Start of batch program.

:runjava
REM --------------------------------------------------------------------------
REM Submit PE Client Command for Intraday Batch Submission
REM --------------------------------------------------------------------------
echo PE Client Intraday Batch Submit Begins

echo Change to PE Client directory and launch PE Client
   
	D:
	cd D:\CIM10\WAR\PE\pe-client
	echo Make PE Client job submition call
	java -jar trm-pe-client.jar -user=trm_batch_usr -password=dummyPassword -jobId=IBJOB0000002
   
	echo Return Code=%errorlevel%
	If %errorlevel% == 0 goto :PROCESSEXIT


:PROCESSEXIT
REM --------------------------------------------------------------------------
REM Exit PE Client Command for Intraday Batch Submission
REM --------------------------------------------------------------------------
echo PE Client Intraday Batch Submit Ends
EXIT
:begin
REM *********************************************************
REM  Derived Reponses Resubmit Rule command file
REM *********************************************************
@echo off
echo Start of batch program.

:runjava
REM --------------------------------------------------------------------------
REM Submit PE Client Command for Derived Reponses Submission
REM --------------------------------------------------------------------------
echo PE Client Derived Reponses Submit Begins

echo Change to PE Client directory and launch PE Client
   
	D:
	cd D:\CIM10\WAR\PE\pe-client
	echo Make PE Client job submition call
	java -jar trm-pe-client.jar -user=trm_batch_usr -password=dummyPassword -jobId=CSJOB0000002
   
	echo Return Code=%errorlevel%
	If %errorlevel% == 0 goto :PROCESSEXIT
        echo PE Client Derived Reponses Submit Fails
        EXIT 1


:PROCESSEXIT
REM --------------------------------------------------------------------------
REM Exit PE Client Command for Derived Reponses Submission
REM --------------------------------------------------------------------------
echo PE Client Derived Reponses Submit Ends
EXIT 0
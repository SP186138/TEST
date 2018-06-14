/* ----------------------------------------------------------------------------
 * This file is used in the DMC Response PE Extension to populate
 * the iCRM.STAGE_DMC_RESP table.
 * File location: ..\WEB-INF\classes\teradata
 * The file depends on the Run_Id passed in from the DMC Response PE.
 * It executes the following steps:
 * - Delete record in log history table to prevent duplicate in case of rerun
 * - Initialize log history table with the start time
 * - Collect statistics on log history table
 * - Delete records in stage response table in case of rerun
 * - Collect statistics on the stage response table
 * - Update log history table with the end time
 * ----------------------------------------------------------------------------

/* Delete records from current run_id to prevent duplicates */

DELETE TRM_LEAD_DB.DMC_RESP_PE_EXT_TABLE_RUN_HIST
WHERE RUN_ID = '@RunId';

/* Initialize DMC_RESP_PE_EXT_TABLE_RUN_HIST table */

INSERT INTO TRM_LEAD_DB.DMC_RESP_PE_EXT_TABLE_RUN_HIST
     (
      DMC_Resp_Tbl_Name,
      Run_Id,
      DMC_Work_Tbl_Insert_Start_Dttm,
      DMC_Work_Tbl_Insert_End_Dttm
     )
SELECT 
      'DMC_Resp_'||'@RunId' AS DMC_Resp_Tbl_Name,
      '@RunId' AS Run_Id,
      Current_Timestamp AS DMC_Work_Tbl_Insert_Start_Dttm,
      NULL AS DMC_Work_Tbl_Insert_End_Dttm;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;	  
      
COLLECT STATISTICS TRM_LEAD_DB.DMC_RESP_PE_EXT_TABLE_RUN_HIST INDEX Run_Id;
      
/* Delete STAGE_DMC_RESP records from current run_id to prevent duplicates */

DELETE iCRM_STAGE_TBL.STAGE_DMC_RESP
WHERE RUN_ID = '@RunId';

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
/* Populate STAGE_DMC_RESP */

INSERT INTO iCRM_STAGE_TBL.STAGE_DMC_RESP
     (
      DMC_Response_Type,
      DMC_Response_Dttm,
      DMC_Bounce_Category,
      DMC_Link_Category,
      DMC_Contact_Id,
      DMC_Output_Id,
      Lead_Key_Id,
      Schema_Id,
      Collateral_Id,
      DMC_Link,
	  Process_Dttm,
      Run_Id
     )
SELECT
      DMC_Response_Type,
      DMC_Response_Dttm,
      DMC_Bounce_Category,
      DMC_Link_Category_Id AS DMC_Link_Category,
      DMC_Contact_Id,
      DMC_Output_Id,
      Lead_Key_Id,
      Schema_Id,
      Collateral_Id,
      DMC_Link,
	  '@ProcessDttm' AS Process_Dttm,
      '@RunId' AS Run_Id
FROM TRM_LEAD_DB.DMC_RESP_@RunId;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

COLLECT STATISTICS iCRM_STAGE_TBL.STAGE_DMC_RESP COLUMN DMC_Contact_Id;
      
/* Update end timestamp */

UPDATE TRM_LEAD_DB.DMC_RESP_PE_EXT_TABLE_RUN_HIST
SET DMC_Work_Tbl_Insert_End_Dttm = Current_Timestamp
WHERE Run_Id = '@RunId';

.QUIT 0;

.LABEL ERROR_END;
.QUIT ERRORCODE;
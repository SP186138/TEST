/*
 * RECDUL795 Provide function that will prevent the generation of outputs that have no eligible leads
 *
 * Use MD_Setting table to control generation of empty outputs.  Except this setting allows control via group submit vs ad hoc
 * 
 * To activate filtering, run the following inserts:
 * INSERT INTO Md_Setting (Setting_Name, Setting_Value, Description, Update_User, Update_Dttm)
 * VALUES ('IGNORE_EMPTY_OUTPUT_GROUP', '1', '1 = do not allow empty output generation; any other value = allow generation of empty outputs', CURRENT_USER, CURRENT_TIMESTAMP);
 * INSERT INTO Md_Setting (Setting_Name, Setting_Value, Description, Update_User, Update_Dttm)
 * VALUES ('IGNORE_EMPTY_OUTPUT_ADHOC', '0', '1 = do not allow empty output generation; any other value = allow generation of empty outputs', CURRENT_USER, CURRENT_TIMESTAMP)    
 *
 */

/*
 * First check to see if we even need to perform the check.
 *
 */
 LOCK ROW FOR ACCESS
 SELECT  
         BC.Batch_Ind,
         COALESCE(AE.Ignore_Empty_Ind, '0') AS Ignore_Empty_ind
 FROM
       /*
        * Determine if running ad hoc or group batch
        */
      (SELECT COALESCE(Batch_Ind, 0) AS Batch_Ind
       FROM   "@CoreDatabase".CR_JOB_HISTORY jh
       LEFT 
       JOIN  (SELECT jh2.Run_Id, 1 AS Batch_Ind
              FROM  "@CoreDatabase".CR_JOB_HISTORY jh2
              JOIN  "@CoreDatabase".CR_JOB j2 ON
                     jh2.Job_Id = j2.Job_Id AND 
                     -- We have to use run id to get all job history records
                     -- because we're looking for the master job (batch)
                     jh2.Run_Id = '@RunId' AND 
                     j2.Job_Type_Cd = 2 -- Group batch job                 
              ) Grp ON
                 jh.Run_Id = Grp.Run_Id
        WHERE jh.Job_History_Id = '@JobHistoryId'
      ) BC
 LEFT 
 JOIN (SELECT     Setting_Name
                , CAST(TRIM(BOTH FROM Setting_Value) AS VARCHAR(1) CHARACTER SET UNICODE) AS Ignore_Empty_Ind
       FROM     "@CoreDatabase".MD_SETTING 
       WHERE     Setting_Name IN ( 'IGNORE_EMPTY_OUTPUT_GROUP', 'IGNORE_EMPTY_OUTPUT_ADHOC')
      ) AE  ON   
         ((BC.Batch_Ind = 1 AND AE.Setting_Name = 'IGNORE_EMPTY_OUTPUT_GROUP') OR 
          (BC.Batch_Ind = 0 AND AE.Setting_Name = 'IGNORE_EMPTY_OUTPUT_ADHOC')
         ) 
WHERE Ignore_Empty_Ind = '1';

/*
 * If no check is desired, just skip this entire process
 */ 

.IF ACTIVITYCOUNT == 0 THEN .GOTO SKIP_FILTER;

DROP TABLE VT_DEL_LIST;

CREATE  VOLATILE
TABLE   VT_DEL_LIST
 (
        Presentation_Template_id  VARCHAR(12) CHARACTER SET LATIN,
        Communication_Id          VARCHAR(12) CHARACTER SET LATIN,
 	      Comm_Plan_Id              VARCHAR(12) CHARACTER SET LATIN,
 	      Step_Id                   VARCHAR(12) CHARACTER SET LATIN,
 	      Message_Id                VARCHAR(12) CHARACTER SET LATIN,
 	      Leaf_Segment_Id           VARCHAR(12) CHARACTER SET LATIN,
 	      Step_Dttm                 TIMESTAMP(6), 	      
 	      Single_Step_Ind           BYTEINT
 )
PRIMARY INDEX(Communication_Id, Comm_Plan_Id, Step_Id, Message_Id, 
              Leaf_Segment_Id, Single_Step_Ind)
ON COMMIT PRESERVE ROWS;

.IF ERRORCODE != 0 THEN .GOTO ERROR;       

DROP TABLE VT_OUT_HIST;

CREATE  VOLATILE
TABLE   VT_OUT_HIST
 (
        Communication_Id          VARCHAR(12) CHARACTER SET LATIN,
 	      Comm_Plan_Id              VARCHAR(12) CHARACTER SET LATIN,
 	      Step_Id                   VARCHAR(12) CHARACTER SET LATIN,
 	      Message_Id                VARCHAR(12) CHARACTER SET LATIN,
 	      Leaf_Segment_Id           VARCHAR(12) CHARACTER SET LATIN,
 	      Step_Dttm                 TIMESTAMP(6), 	      
 	      Single_Step_Ind           BYTEINT
 )
UNIQUE PRIMARY INDEX(Communication_Id, Comm_Plan_Id, Step_Id, Message_Id, 
                     Leaf_Segment_Id, Single_Step_ind)
ON COMMIT PRESERVE ROWS;

.IF ERRORCODE != 0 THEN .GOTO ERROR;       

LOCK TABLE "@CoreDatabase".RT_OUTPUT_HISTORY FOR ACCESS
INSERT 
INTO     VT_OUT_HIST
 (
        Communication_Id,
 	      Comm_Plan_Id,
 	      Step_Id,
 	      Message_Id,
 	      Leaf_Segment_Id,
 	      Step_Dttm,
 	      Single_Step_Ind
 )
SELECT 
         OH.Communication_Id
       , OH.Comm_Plan_Id
       , OH.Step_Id     
       , OH.Message_Id
       , OH.Leaf_Segment_Id
       , OH.Communication_Process_Dttm AS Step_Dttm 
       , OH.Single_Step_Ind
FROM
       "@CoreDatabase".RT_OUTPUT_HISTORY OH
WHERE  OH.Run_Id = '@RunId'
GROUP 
   BY  1,2,3,4,5,6,7;

.IF ERRORCODE != 0 THEN .GOTO ERROR;       

COLLECT STATS VT_OUT_HIST COLUMN(Single_Step_Ind);
COLLECT STATS VT_OUT_HIST INDEX(Communication_Id, Comm_Plan_Id, Step_Id, Message_Id, 
                                Leaf_Segment_Id, Single_Step_ind);
/*
 * Check to see if collateral history should be used.  Defaults to No
 */
LOCK ROW FOR ACCESS
SELECT 'Using Collateral History'
FROM   "@CoreDatabase".MD_SETTING 
WHERE  Setting_Name = 'COLLATERAL_HISTORY_ARCHIVE_PRD' AND
       TRIM(BOTH FROM COALESCE(Setting_Value, '0')) > '0';

.IF ERRORCODE != 0 THEN .GOTO ERROR;       
.IF ACTIVITYCOUNT != 0 THEN .GOTO USE_COLL_HIST;       
       
/* 
 *  Identify template rows that have no eligible leads 
 */
 
/*
 * Using standard lh tables (lh_realized_lead/lh_current_lead) 
 * Target rows for deletion where those rows had no corresponding leads 
 * in the lead history table.
 */
 LOCK TABLE "@LeadDatabase".LH_CURRENT_LEAD FOR ACCESS
 LOCK TABLE "@LeadDatabase".LH_REALIZED_LEAD FOR ACCESS
 INSERT INTO VT_DEL_LIST
 (
        Communication_Id,
 	      Comm_Plan_Id,
 	      Step_Id,
 	      Message_Id,
 	      Leaf_Segment_Id,
 	      Step_Dttm,
 	      Single_Step_Ind
 )
SELECT    OH.Communication_Id
         ,OH.Comm_Plan_Id
         ,OH.Step_Id
         ,OH.Message_Id
         ,OH.Leaf_Segment_Id
         ,OH.Step_Dttm
         ,OH.Single_Step_Ind
  FROM   "@LeadDatabase".LH_CURRENT_LEAD CL  
  RIGHT  
  JOIN   VT_OUT_HIST OH ON    
            OH.Communication_Id = CL.Communication_Id AND 
            OH.Comm_Plan_Id = CL.Comm_Plan_Id AND 
            OH.Step_Id = CL.Step_Id AND
            OH.Message_Id = CL.Message_Id AND
            OH.Leaf_Segment_Id = CL.Leaf_Segment_Id AND
            OH.Step_Dttm = CL.Step_Dttm AND 
            OH.Single_Step_Ind = 0 -- multistep
 WHERE   CL.Communication_Id IS NULL AND OH.Single_Step_Ind = 0
 GROUP 
    BY   1,2,3,4,5,6,7    
UNION ALL 
SELECT    OH.Communication_Id
         ,OH.Comm_Plan_Id
         ,OH.Step_Id
         ,OH.Message_Id
         ,OH.Leaf_Segment_Id
         ,OH.Step_Dttm
         ,OH.Single_Step_Ind               
  FROM   "@LeadDatabase".LH_REALIZED_LEAD RL
  RIGHT 
  JOIN   VT_OUT_HIST OH ON    
            OH.Communication_Id = RL.Communication_Id AND 
            OH.Comm_Plan_Id = RL.Comm_Plan_Id AND 
            OH.Step_Id = RL.First_Step_Id AND
            OH.Message_Id = RL.First_Message_Id AND
            OH.Leaf_Segment_Id = RL.Leaf_Segment_Id AND
            OH.Step_Dttm = RL.Selection_Dttm AND 
            OH.Single_Step_Ind = 1 -- single step
 WHERE   RL.Communication_Id IS NULL AND OH.Single_Step_Ind = 1                      
 GROUP 
    BY   1,2,3,4,5,6,7;

.IF ERRORCODE != 0 THEN .GOTO ERROR;       
     
.GOTO DEL_EMPTY;        
.LABEL USE_COLL_HIST;

/*
 * Implementation is using collateral history for output
 */  
LOCK TABLE "@LeadDatabase".LH_COLLATERAL_HISTORY FOR ACCESS 
INSERT INTO VT_DEL_LIST
(
        Communication_Id,
	      Comm_Plan_Id,
	      Step_Id,
	      Message_Id,
	      Leaf_Segment_Id,
	      Step_Dttm,
	      Single_Step_Ind
)
SELECT    OH.Communication_Id
         ,OH.Comm_Plan_Id
         ,OH.Step_Id
         ,OH.Message_Id
         ,OH.Leaf_Segment_Id
         ,OH.Step_Dttm
         ,OH.Single_Step_Ind
  FROM   "@LeadDatabase".LH_COLLATERAL_HISTORY CH
RIGHT 
  JOIN   VT_OUT_HIST OH ON    
            OH.Communication_Id = CH.Communication_Id AND 
            OH.Comm_Plan_Id = CH.Comm_Plan_Id AND 
            OH.Step_Id = CH.Step_Id AND
            OH.Message_Id = CH.Message_Id AND
			/*Applied for CIM 7.0.1.5*/
			/*OH.Leaf_Segment_Id = CH.Leaf_Segment_Id AND
            OH.Step_Dttm = CH.Step_Dttm */
            ((CH.Selection_Dttm = oh.Step_Dttm AND
                CH.Step_Dttm = oh.Step_Dttm AND
                CH.Leaf_Segment_Id = oh.Leaf_Segment_Id 
                --AND CH.Segment_Run_Id = oh.Segment_Run_Id
                )
                OR
                (oh.Step_Dttm IS NULL AND
                 oh.Leaf_Segment_Id IS NULL AND
                 --oh.Segment_Run_Id IS NULL AND
                 CH.Step_Dttm = 
                CAST('@ProcessDttm' AS TIMESTAMP(6))
            ))
 WHERE  CH.Communication_Id IS NULL
 GROUP 
    BY   1,2,3,4,5,6,7;

.IF ERRORCODE != 0 THEN .GOTO ERROR;       

.LABEL DEL_EMPTY;

COLLECT STATS VT_DEL_LIST INDEX(Communication_Id, Comm_Plan_Id, Step_Id, Message_Id, 
                                Leaf_Segment_Id, Single_Step_ind);

       
-- Remove outputs (templates) that don't have any eligible leads
DELETE OH
FROM   "@CoreDatabase".RT_OUTPUT_HISTORY OH,
        VT_DEL_LIST DL 
WHERE   OH.Communication_Id = DL.Communication_Id AND
        OH.Comm_Plan_Id = DL.Comm_Plan_Id AND 
        OH.Step_Id = DL.Step_Id AND 
        OH.Message_Id = DL.Message_Id AND 
		/*Applied for CIM 7.0.1.5*/        
		/*OH.Leaf_Segment_Id = DL.Leaf_Segment_Id AND 
        OH.Communication_Process_Dttm = DL.Step_Dttm AND */
        OH.Single_Step_Ind = DL.Single_Step_Ind AND 
        OH.Run_Id = '@RunId';

.IF ERRORCODE != 0 THEN .GOTO ERROR;           

DROP TABLE VT_DEL_LIST;
DROP TABLE VT_OUT_HIST;
          
.LABEL SKIP_FILTER;          

.QUIT 0;

.LABEL ERROR;

.QUIT ERRORCODE;
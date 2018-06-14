/*
Check if the coupon process should be run 
*/

/*check unique coupon for non-first steps*/

LOCK ROW FOR ACCESS
SELECT
    1
FROM
    (SELECT distinct communication_id,comm_plan_id,collateral_id,step_id from "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL) t1
JOIN
    "@CoreDatabase".EX_COLLATERAL t2
ON
    t1.Collateral_Id=t2.Collateral_Id
JOIN
    "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE t3
ON
    t2.CNTNT_INCTV_ID=t3.Selection_Plan_Id
JOIN
	"@CoreDatabase".CM_COMM_PLAN_STEP T4
ON
	T1.Step_Id=T4.Step_Id
	and T1.Comm_Plan_Id=T4.Comm_Plan_Id
	AND T4.First_Step_Ind=0
JOIN
	"@LeadDatabase".LH_RUN_HISTORY T5
ON
	t1.Communication_id=T5.Communication_Id	
WHERE
    t3.Schema_Element_Id=94
    AND t3.key2_val='CPY'
    AND t3.Key3_Val='I'
    AND t5.Run_Id='@RunId'
;    

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.IF ACTIVITYCOUNT = 0 THEN .GOTO SKIP_PROCESS;

.LABEL UNIQUE_COUPONS;

DELETE FROM "@CoreDatabase".COUPON_EMAIL
WHERE
	Run_Id='@RunId';

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

DROP TABLE COUPON_COMPONENT_LOCK@WorkingPartitionId;

LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".EX_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
LOCK TABLE "@LeadDatabase".LH_RUN_HISTORY FOR ACCESS
LOCK TABLE "@CoreDatabase".CR_COMPONENT_LOCK FOR ACCESS
LOCK TABLE "@CoreDatabase".CR_JOB_HISTORY FOR ACCESS
LOCK TABLE "@CoreDatabase".CM_COMM_PLAN_STEP FOR ACCESS
CREATE VOLATILE TABLE COUPON_COMPONENT_LOCK@WorkingPartitionId
AS
(
SELECT
    Key1_Val AS INCTV_NBR_Lock
    ,12 AS Component_Type_Cd             
    ,'@JobHistoryId' AS Job_History_Id             
    ,CURRENT_USER AS Update_User
    ,CURRENT_TIMESTAMP AS Update_Dttm
    ,t1.Communication_Id
	,t1.Step_Id
    ,'@RunId' AS Run_Id
    ,1 AS EMAIL_TYPE_CD
    ,t6.Communication_Id AS Blocking_Communication_Id
    ,t5.Run_Id AS Blocking_Run_Id
FROM
    (SELECT distinct communication_id,comm_plan_id,collateral_id,step_Id from "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL) t1
JOIN
    "@CoreDatabase".EX_COLLATERAL t2
ON
    t1.Collateral_Id=t2.Collateral_Id
JOIN
    "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE t3
ON
    t2.CNTNT_INCTV_ID=t3.Selection_Plan_Id
LEFT JOIN
    "@CoreDatabase".CR_COMPONENT_LOCK t4
ON
    INCTV_NBR_Lock=Component_Id
LEFT JOIN
    "@CoreDatabase".CR_JOB_HISTORY t5
ON
    t4.Job_History_Id=t5.Job_History_Id
LEFT JOIN
    "@LeadDatabase".LH_RUN_HISTORY t6
ON
    t5.Run_Id=t6.Run_Id
JOIN
	"@CoreDatabase".CM_COMM_PLAN_STEP t7
ON
	t1.Step_Id=t7.Step_Id
	and t1.Comm_Plan_Id=t7.Comm_Plan_Id
	AND t7.First_Step_Ind=0	
JOIN
	"@LeadDatabase".LH_RUN_HISTORY t8
ON
	t1.Communication_id=t8.Communication_Id		
WHERE
    t3.Schema_Element_Id=94
    AND t3.key2_val='CPY'
    AND t3.Key3_Val='I'
    AND t8.Run_Id='@RunId'
) WITH DATA PRIMARY INDEX (INCTV_NBR_Lock)
ON COMMIT PRESERVE ROWS
;  

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;


/*Exclude blocked communications*/
INSERT INTO "@CoreDatabase".COUPON_EMAIL
	(Communication_Id              
	,Run_Id                        
	,Step_Dttm                     
	,Email_Type_Cd                 
	,INCTV_NBR                     
	,No_Coupons                    
	,No_Leads                      
	,Locking_Communication_Id      
	,Locking_Run_Id                
	,Step_Id                       
	)
SELECT DISTINCT
	  Communication_Id
	 ,Run_Id
	 ,TIMESTAMP'@ProcessDttm'
	 ,Email_Type_Cd
	 ,INCTV_NBR_Lock
	 ,NULL
	 ,NULL
	 ,Blocking_Communication_Id
	 ,Blocking_Run_Id
	 ,Step_Id
FROM	
	COUPON_COMPONENT_LOCK@WorkingPartitionId
WHERE
	Blocking_Run_Id IS NOT NULL
;	

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

/*LOCK INCENTIVES*/
INSERT INTO "@CoreDatabase".CR_COMPONENT_LOCK
(Component_Id                  
,Component_Type_Cd             
,Job_History_Id                
,Update_User                   
,Update_Dttm                   
)
SELECT
	INCTV_NBR_Lock
    ,Component_Type_Cd             
    ,Job_History_Id             
    ,Update_User
    ,Update_Dttm
FROM	
	COUPON_COMPONENT_LOCK@WorkingPartitionId
WHERE
	Blocking_Run_Id IS NULL
;	
	
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
	
/*
Check if enough coupons are available
*/
DROP TABLE CHECK_COUPON_NUMBER@WorkingPartitionId;


LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
LOCK TABLE "@CoreDatabase".ex_collateral FOR ACCESS
LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL FOR ACCESS
LOCK TABLE "@LeadDatabase".LH_RUN_HISTORY FOR ACCESS
LOCK TABLE "@LeadDatabase".LH_COLLATERAL_HISTORY FOR ACCESS
LOCK TABLE "@CoreDatabase".CM_COMM_PLAN_STEP FOR ACCESS
CREATE VOLATILE TABLE CHECK_COUPON_NUMBER@WorkingPartitionId
AS
(SELECT
    s2.Communication_Id
	,s2.Collateral_Id
	,s1.Step_Id
    ,'@RunId' AS Run_Id
    ,2 AS Email_Type_Cd
    ,s1.INCTV_NBR
    ,zeroifnull(#coupons/count(*) over (partition by s1.INCTV_NBR)) AS No_Coupons --if one coupon is used in multiple collaterals then we are using the average number
    ,zeroifnull(#leads) AS No_Leads
FROM    
(
SELECT 
    t4.Communication_Id
	,t4.Step_Id
    ,t4.Collateral_Id
    ,t2.Key1_Val AS INCTV_NBR
    ,COUNT(T1.INCTV_NBR) #coupons
FROM 
	TRM_VIEWS_DB.EXTRN_COUPN T1
RIGHT JOIN
    "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE t2
ON
    t1.MKTNG_PGM_NBR=t2.Key4_Val
    AND t1.INCTV_NBR=t2.Key1_Val
    AND t1.EXTRN_COUPN_STATUS_CD='UN'
RIGHT JOIN
    "@CoreDatabase".ex_collateral t3
ON
    t2.Selection_Plan_Id=t3.CNTNT_INCTV_ID
RIGHT JOIN
    (SELECT distinct s1.communication_id,s1.Comm_Plan_Id,s1.collateral_id,s1.step_id,s2.Run_Id from "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL s1
	JOIN "@LeadDatabase".LH_RUN_HISTORY s2 ON s1.communication_id=s2.COMMUNICATION_ID
	JOIN "@CoreDatabase".CM_COMM_PLAN_STEP s3 ON s1.Step_Id=s3.Step_Id and s1.Comm_Plan_Id=s3.Comm_Plan_Id AND s3.First_Step_Ind=0) t4
ON
    t3.Collateral_Id=t4.Collateral_Id	
WHERE
	t4.Run_Id='@RunId'
	AND t2.Schema_Element_Id=94
GROUP BY 1,2,3,4
) S1
JOIN
(
SELECT 
    Communication_Id
    ,Collateral_Id
    ,COUNT(*) #leads 
FROM 
    "@LeadDatabase".LH_COLLATERAL_HISTORY
WHERE	
	Step_Dttm=TIMESTAMP'@ProcessDttm'	
GROUP BY 1,2    
 ) S2
 ON
    S1.Communication_Id=S2.Communication_Id
    AND S1.Collateral_Id=S2.Collateral_Id
) WITH DATA PRIMARY INDEX (INCTV_NBR)
ON COMMIT PRESERVE ROWS
;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

INSERT INTO "@CoreDatabase".COUPON_EMAIL
	(Communication_Id              
	,Run_Id                        
	,Step_Dttm                     
	,Email_Type_Cd                 
	,INCTV_NBR                     
	,No_Coupons                    
	,No_Leads                      
	,Locking_Communication_Id      
	,Locking_Run_Id                
	,Step_Id                       
	)
SELECT DISTINCT
	  Communication_Id
	 ,Run_Id
	 ,TIMESTAMP'@ProcessDttm'
	 ,Email_Type_Cd
	 ,INCTV_NBR
	 ,No_Coupons
	 ,No_Leads 
	 ,NULL
	 ,NULL
	 ,Step_Id
FROM	
	CHECK_COUPON_NUMBER@WorkingPartitionId
WHERE 
	No_Coupons<No_Leads;	
;	

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

SELECT * FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId';

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.IF ACTIVITYCOUNT = 0 THEN .GOTO ASSIGN_UNIQUE_COUPONS;

/*Exlude communications from processing*/
DELETE "@LeadDatabase".LH_CURRENT_LEAD WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Step_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
INSERT INTO "@LeadDatabase".LH_CURRENT_LEAD
(
        Communication_Id,
        Comm_Plan_Id,
		@All_LeadDb_Elements,
        Selection_Dttm,
        Selection_Group_Ord,
        Step_Id,
        Step_Dttm,
        Message_Id,
        Lead_Status_Cd,
        Status_Dttm,
        Last_Contact_Dttm,
        Next_Action_Dttm,
        Reminder_Dttm,
        Timeout_Delay_Num,
        Timeout_Start_Dttm,
        Calendar_Id,
        Leaf_Segment_Id,
        Segment_Run_Id,
        Monitoring_Ind,
        Monitoring_Timeout_Dttm
)
SELECT  MD.Communication_Id,
        MD.Comm_Plan_Id,
		MD.@All_LeadDb_Elements,
        MD.Selection_Dttm,
        MD.Selection_Group_Ord,
        MD.Step_Id,
        MD.Step_Dttm,
        MD.Message_Id,
        1 /* Active */ Lead_Status_Cd,
        MD.Step_Dttm AS Status_Dttm,
        NULL AS Last_Contact_Dttm,
        CASE
            WHEN '1'='1' 
            THEN MD.Step_Dttm + (INTERVAL '1' DAY * ZEROIFNULL(MSG.Timeout_Delay_Num))
            ELSE MD.Step_Dttm
        END AS Next_Action_Dttm,
        (CASE MSG.Timeout_Reminder_Ind
            WHEN 1 THEN 
                (CASE MSG.Timeout_Reminder_Origin_Cd
                    -- Sourced from arrival date
                    WHEN 1 THEN MD.Step_Dttm + (INTERVAL '1' DAY * ZEROIFNULL(MSG.Timeout_Reminder_Num)) 
                    -- Sourced from timeout date
                    WHEN 4 THEN CASE
                                WHEN '1'='1' 
                                THEN MD.Step_Dttm + (INTERVAL '1' DAY * ZEROIFNULL(MSG.Timeout_Reminder_Num))
                                ELSE MD.Step_Dttm
                                END - (INTERVAL '1' DAY * ZEROIFNULL(MSG.Timeout_Reminder_Num))
                  --  ELSE MD.Last_Reminder_Dttm
                END)
            WHEN 0 THEN NULL       
        END) Reminder_Dttm,
        MSG.Timeout_Delay_Num,
        MD.Step_Dttm AS Timeout_Start_Dttm,
        NULL AS Calendar_Id,
        MD.Leaf_Segment_Id,
        MD.Segment_Run_Id,
        0 Monitoring_Ind,
        NULL (TIMESTAMP) Monitoring_Timeout_Dttm

FROM "@LeadDatabase".LH_CHANNEL_HISTORY MD
JOIN "@LeadDatabase".LH_LEAD_STATUS_HISTORY LSH
ON
	MD.REGIS_PRSNA_ID=LSH.REGIS_PRSNA_ID
	AND MD.Communication_Id=LSH.Communication_Id
	AND MD.Selection_Dttm=LSH.Selection_Dttm
	AND MD.Step_Id=LSH.Step_Id
	AND MD.Step_Dttm=LSH.Step_Dttm
LEFT JOIN "@CoreDatabase".RT_MESSAGE MSG
ON MD.Message_Id=MSG.Message_Id
AND MD.Communication_Id=MSG.Communication_Id
WHERE MD.Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') 
AND LSH.Status_Dttm=TIMESTAMP'@ProcessDttm'
AND LSH.Lead_Status_Cd NOT IN (1, 2, 4, 11, 18);
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE "@LeadDatabase".LH_LEAD_STATUS_HISTORY WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Status_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE "@LeadDatabase".LH_LEAD_KEY_HISTORY WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Step_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE "@LeadDatabase".LH_CHANNEL_HISTORY WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Step_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE "@LeadDatabase".LH_CONTACT_HISTORY WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Step_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE "@LeadDatabase".LH_DELIVERY_HISTORY WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Step_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE "@LeadDatabase".LH_COLLATERAL_HISTORY WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Step_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
INSERT "@LeadDatabase".RT_CHANNEL_RESPONSE
	(HSHLD_PRSNA_ID                
	,MATCHD_CNSMR_PRSNA_ID         
	,REGIS_PRSNA_ID                
	,Response_Id                   
	,Response_Dttm                 
	,Response_Channel_Class_Id     
	,Response_Channel_Instance_Id  
	,Response_Collateral_Id        
	,Response_Processing_Cd        
	,Communication_Id              
	,Comm_Plan_Id                  
	,Selection_Dttm                
	,Selection_Group_Ord           
	,Step_Id                       
	,Step_Dttm                     
	,Message_Id                                
	,Package_Id                    
	,Reminder_Dttm                 
	,Hold_Period_Num               
	,Hold_Release_Dt               
	,Contact_Dttm                  
	,Contact_Cnt                   
	,Delivery_Dttm                 
	,Delivery_Cnt                  
	,Hard_Contact_Ind                               
	,Notification_Dttm                           
	,Lead_Key_Id                   
	,Response_Value_Amt            
	,Response_Source_Type_Cd)
SELECT DISTINCT
	 HSHLD_PRSNA_ID                
	,MATCHD_CNSMR_PRSNA_ID         
	,REGIS_PRSNA_ID                
	,Response_Id                   
	,Response_Dttm                 
	,Response_Channel_Class_Id     
	,Response_Channel_Instance_Id  
	,Response_Collateral_Id        
	,Response_Processing_Cd        
	,Communication_Id              
	,Comm_Plan_Id                  
	,Selection_Dttm                
	,Selection_Group_Ord           
	,Step_Id                       
	,Step_Dttm                     
	,Message_Id                                
	,Package_Id                    
	,Reminder_Dttm                 
	,Hold_Period_Num               
	,Hold_Release_Dt               
	,Contact_Dttm                  
	,Contact_Cnt                   
	,Delivery_Dttm                 
	,Delivery_Cnt                  
	,Hard_Contact_Ind                               
	,Notification_Dttm                           
	,Lead_Key_Id                   
	,Response_Value_Amt            
	,Response_Source_Type_Cd       
FROM "@LeadDatabase".LH_CHANNEL_RESPONSE 
WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') 
and Status_Dttm=TIMESTAMP'@ProcessDttm'
;
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE "@LeadDatabase".LH_CHANNEL_RESPONSE WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Status_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
INSERT INTO "@LeadDatabase".RT_RESPONSE_REQUEST
	(HSHLD_PRSNA_ID                
	,MATCHD_CNSMR_PRSNA_ID         
	,REGIS_PRSNA_ID                
	,Response_Id                   
	,Response_Dttm                 
	,Request_Type_Cd               
	,Request_Data_Txt              
	,Communication_Id              
	,Comm_Plan_Id                  
	,Selection_Dttm                
	,Selection_Group_Ord           
	,Step_Id                       
	,Step_Dttm                     
	,Message_Id                                  
	,Package_Id                                         
	,Lead_Key_Id) 
SELECT DISTINCT
	HSHLD_PRSNA_ID                
	,MATCHD_CNSMR_PRSNA_ID         
	,REGIS_PRSNA_ID                
	,Response_Id                   
	,Response_Dttm                 
	,Request_Type_Cd               
	,Request_Data_Txt              
	,Communication_Id              
	,Comm_Plan_Id                  
	,Selection_Dttm                
	,Selection_Group_Ord           
	,Step_Id                       
	,Step_Dttm                     
	,Message_Id                                  
	,Package_Id                                         
	,Lead_Key_Id                   
FROM "@LeadDatabase".LH_RESPONSE_REQUEST 
WHERE (Lead_Key_Id,Response_Dttm) IN
(SELECT Lead_Key_Id,Response_Dttm FROM "@LeadDatabase".RT_CHANNEL_RESPONSE);
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE FROM "@LeadDatabase".LH_RESPONSE_REQUEST WHERE (Lead_Key_Id,Response_Dttm) IN (SELECT Lead_Key_Id,Response_Dttm FROM "@LeadDatabase".RT_CHANNEL_RESPONSE);
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
DELETE "@LeadDatabase".LH_RUN_HISTORY WHERE Communication_Id IN (SELECT Communication_Id FROM "@CoreDatabase".COUPON_EMAIL WHERE Run_Id='@RunId') and Process_Dttm=TIMESTAMP'@ProcessDttm';
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;


.LABEL ASSIGN_UNIQUE_COUPONS;

/*CREATE WORKING TABLE*/

DROP TABLE "@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId;

/*CREATE TABLE "@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId
AS
icrm_tbl.EXTRN_COUPN_ASSIGN
WITH NO DATA;*/

CREATE TABLE "@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId
     (
      INCTV_NBR INTEGER NOT NULL,
      MKTNG_PGM_NBR INTEGER NOT NULL,
      EXTRN_COUPN_CD VARCHAR(100) CHARACTER SET UNICODE NOT CASESPECIFIC NOT NULL,
      EXTRN_COUPN_DATA_SRCE_NBR INTEGER NOT NULL,
      TRM_LEAD_KEY VARCHAR(20) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
      LEGAL_ENT_NBR SMALLINT NOT NULL,
      REGIS_PRSNA_ID INTEGER NOT NULL,
      CAMPAIGN_ID VARCHAR(20) CHARACTER SET LATIN NOT CASESPECIFIC,
      CAMPAIGN_DATA_SRCE_NBR INTEGER,
      CAMPAIGN_RUN_ID VARCHAR(12) CHARACTER SET LATIN NOT CASESPECIFIC,
      LOG_SOURCE_ID DECIMAL(18,0),
      LOG_UPDATE_USER VARCHAR(20) CHARACTER SET LATIN NOT CASESPECIFIC,
      LOG_LOAD_ID VARCHAR(8) CHARACTER SET LATIN NOT CASESPECIFIC)
PRIMARY INDEX EXTRN_COUPN_ASSIGN_NUPI ( MKTNG_PGM_NBR ,REGIS_PRSNA_ID )
PARTITION BY MKTNG_PGM_NBR 
UNIQUE INDEX ( INCTV_NBR ,MKTNG_PGM_NBR ,EXTRN_COUPN_CD ,EXTRN_COUPN_DATA_SRCE_NBR ,
TRM_LEAD_KEY )
INDEX ( INCTV_NBR ,EXTRN_COUPN_CD );

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

DROP TABLE "@LeadDatabase".WK_LEADS_NUMBERS@WorkingPartitionId;

CREATE TABLE "@LeadDatabase".WK_LEADS_NUMBERS@WorkingPartitionId
(
    Communication_Id VARCHAR(12)
    ,Collateral_Id VARCHAR(12)
	,Step_Id VARCHAR(12)
    ,INCTV_NBR INTEGER
    ,Lead_Key_Id VARCHAR(18)
    ,REGIS_PRSNA_ID INTEGER
    ,Run_Id VARCHAR(12)
    ,Lead_Number BIGINT
) PRIMARY INDEX(REGIS_PRSNA_ID);

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

DROP TABLE "@LeadDatabase".WK_COUPON_NUMBERS@WorkingPartitionId;

CREATE TABLE "@LeadDatabase".WK_COUPON_NUMBERS@WorkingPartitionId
(
    Communication_Id VARCHAR(12)
    ,Collateral_Id VARCHAR(12)
	,Step_Id VARCHAR(12)
    ,INCTV_NBR INTEGER
    ,EXTRN_COUPN_CD VARCHAR(100) CHARACTER SET UNICODE
    ,Coupon_Number BIGINT
	,MKTNG_PGM_NBR INTEGER
	,LEGAL_ENT_NBR INTEGER
	,EXTRN_COUPN_DATA_SRCE_NBR INTEGER
) PRIMARY INDEX (EXTRN_COUPN_CD);

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
LOCK TABLE "@CoreDatabase".ex_collateral FOR ACCESS
LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL FOR ACCESS
LOCK TABLE "@LeadDatabase".LH_RUN_HISTORY FOR ACCESS
LOCK TABLE "@CoreDatabase".CM_COMM_PLAN_STEP FOR ACCESS
INSERT INTO "@LeadDatabase".WK_COUPON_NUMBERS@WorkingPartitionId
SELECT 
    t4.Communication_Id
    ,t4.Collateral_Id
	,t4.Step_Id
    ,t1.INCTV_NBR
    ,t1.EXTRN_COUPN_CD
    ,ROW_NUMBER() OVER (PARTITION BY t4.Communication_Id,t4.Collateral_Id,t1.INCTV_NBR ORDER BY 1) AS Coupon_Number
    ,t1.MKTNG_PGM_NBR
    ,t1.LEGAL_ENT_NBR 
    ,t1.EXTRN_COUPN_DATA_SRCE_NBR
FROM 
	TRM_VIEWS_DB.EXTRN_COUPN T1
JOIN
    "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE t2
ON
    t1.MKTNG_PGM_NBR=t2.Key4_Val
    AND t1.INCTV_NBR=t2.Key1_Val
    AND t1.EXTRN_COUPN_STATUS_CD='UN'
    AND t2.Schema_Element_Id=94
JOIN
    "@CoreDatabase".ex_collateral t3
ON
    t2.Selection_Plan_Id=t3.CNTNT_INCTV_ID
JOIN
    (SELECT distinct s1.communication_id,s1.Comm_Plan_Id,s1.collateral_id,s1.step_id,s2.Run_Id from "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL s1
	JOIN "@LeadDatabase".LH_RUN_HISTORY s2 ON s1.communication_id=s2.COMMUNICATION_ID
	JOIN "@CoreDatabase".CM_COMM_PLAN_STEP s3 ON s1.Step_Id=s3.Step_Id and s1.Comm_Plan_Id=s3.Comm_Plan_Id AND s3.First_Step_Ind=0) t4
ON
    t3.Collateral_Id=t4.Collateral_Id	
WHERE
	t4.Run_Id='@RunId'	
;    

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

LOCK TABLE "@CoreDatabase".ex_collateral FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_LOGICAL_SEGMENT FOR ACCESS
LOCK TABLE "@LeadDatabase".LH_RUN_HISTORY FOR ACCESS
LOCK TABLE "@LeadDatabase".LH_COLLATERAL_HISTORY FOR ACCESS
LOCK TABLE "@LeadDatabase".LH_LEAD_KEY_HISTORY FOR ACCESS
INSERT INTO "@LeadDatabase".WK_LEADS_NUMBERS@WorkingPartitionId
SELECT 
    t1.Communication_Id
    ,t1.Collateral_Id
	,t1.Step_Id
    ,t4.Key1_Val AS INCTV_NBR
    ,t2.Lead_Key_Id
    ,t1.REGIS_PRSNA_ID
    ,'@RunId'
	,ROW_NUMBER() OVER (PARTITION BY t1.Communication_Id,t1.Step_Id,t1.Collateral_Id,t4.Key1_Val ORDER BY 1) AS Lead_Number
FROM 
	"@LeadDatabase".LH_COLLATERAL_HISTORY t1
JOIN
    "@LeadDatabase".LH_LEAD_KEY_HISTORY t2
ON
    t1.Communication_Id=t2.Communication_Id
    AND T1.Comm_Plan_Id=t2.Comm_Plan_Id
    AND t1.REGIS_PRSNA_ID=t2.REGIS_PRSNA_ID
    AND t1.HSHLD_PRSNA_ID=t2.HSHLD_PRSNA_ID
    AND t1.MATCHD_CNSMR_PRSNA_ID=t2.MATCHD_CNSMR_PRSNA_ID
    AND t1.Selection_Dttm=t2.Selection_Dttm
    AND t1.Selection_Group_Ord=t2.Selection_Group_Ord
    AND t1.Step_Id=t2.Step_Id
    AND t1.Step_Dttm=t2.Step_Dttm
    AND t1.Message_Id=t2.Message_Id
JOIN
    "@CoreDatabase".ex_collateral t3
ON
    t1.Collateral_Id=t3.Collateral_Id
JOIN
    "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE t4
ON
    t3.CNTNT_INCTV_ID=t4.Selection_Plan_Id
    AND t4.Schema_Element_Id=94
    AND key2_val='CPY'
    AND Key3_Val='I'    
JOIN
	"@LeadDatabase".LH_RUN_HISTORY t5	
ON	
	t1.Step_Dttm=t5.Process_Dttm
	and t1.Communication_Id=t5.Communication_Id	
WHERE
    t5.Run_Id='@RunId'
;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

INSERT INTO "@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId 
(INCTV_NBR                     
,MKTNG_PGM_NBR                 
,EXTRN_COUPN_CD                
,EXTRN_COUPN_DATA_SRCE_NBR     
,TRM_LEAD_KEY                  
,LEGAL_ENT_NBR                 
,REGIS_PRSNA_ID                
,CAMPAIGN_ID                   
,CAMPAIGN_DATA_SRCE_NBR        
,CAMPAIGN_RUN_ID               
,LOG_SOURCE_ID                 
,LOG_UPDATE_USER               
,LOG_LOAD_ID                   
)
SELECT
	t1.INCTV_NBR                     
	,t1.MKTNG_PGM_NBR                 
	,t1.EXTRN_COUPN_CD                
	,t1.EXTRN_COUPN_DATA_SRCE_NBR     
	,t2.lead_key_id AS TRM_LEAD_KEY                  
	,t1.LEGAL_ENT_NBR                 
	,t2.REGIS_PRSNA_ID                
	,t2.Communication_Id                   
	,'1234' AS CAMPAIGN_DATA_SRCE_NBR        
	,t2.Run_Id               
	,@WorkingPartitionId AS LOG_SOURCE_ID                 
	,CURRENT_USER LOG_UPDATE_USER               
	,'23' AS LOG_LOAD_ID 
FROM
	"@LeadDatabase".WK_COUPON_NUMBERS@WorkingPartitionId T1
JOIN	
	"@LeadDatabase".WK_LEADS_NUMBERS@WorkingPartitionId T2
ON	
	t1.communication_id=t2.communication_id
	AND t1.Collateral_Id=t2.Collateral_Id
	AND t1.Step_Id=t2.Step_Id
	AND t1.inctv_nbr=t2.inctv_nbr
	AND t1.coupon_number=t2.lead_number
;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;


/*INSERT INTO EXTRN_COUPN_ASSIGN*/
INSERT TRM_VIEWS_DB.EXTRN_COUPN_ASSIGN
SELECT * FROM "@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

/*UPDATE EXTRN_COUPN*/
UPDATE T1
FROM
    TRM_VIEWS_DB.EXTRN_COUPN T1
    ,"@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId T2
SET 
	EXTRN_COUPN_STATUS_CD='AS'
WHERE
    T1.EXTRN_COUPN_CD=t2.EXTRN_COUPN_CD
    AND t1.INCTV_NBR=t2.INCTV_NBR                     
    AND t1.MKTNG_PGM_NBR=t2.MKTNG_PGM_NBR
    AND t1.EXTRN_COUPN_DATA_SRCE_NBR=t2.EXTRN_COUPN_DATA_SRCE_NBR
    AND EXTRN_COUPN_STATUS_CD='UN'
;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

/*INSERT INTO "@LeadDatabase".CSP_COUPON_HISTORY*/
LOCK TABLE "@LeadDatabase".LH_LEAD_KEY_HISTORY FOR ACCESS 
LOCK TABLE "@LeadDatabase".LH_RUN_HISTORY FOR ACCESS
INSERT INTO "@LeadDatabase".CSP_COUPON_HISTORY
(COMMUNICATION_ID              
,COMM_PLAN_ID                  
,HSHLD_PRSNA_ID                
,MATCHD_CNSMR_PRSNA_ID         
,REGIS_PRSNA_ID                
,SELECTION_DTTM                
,SELECTION_GROUP_ORD           
,STEP_ID                       
,STEP_DTTM                     
,MESSAGE_ID                    
,LEAD_KEY_ID                   
,LEAD_KEY_SK                   
,EXT_LEAD_KEY                  
,LEGAL_ENT_NBR                 
,EXTRN_COUPN_CD_1              
,EXTRN_COUPN_CD_2              
,EXTRN_COUPN_CD_3              
,EXTRN_COUPN_CD_4              
,EXTRN_COUPN_CD_5              
,EXTRN_COUPN_CD_6              
,EXTRN_COUPN_CD_7              
,EXTRN_COUPN_CD_8              
,EXTRN_COUPN_CD_9              
,EXTRN_COUPN_CD_10             
,EXTRN_COUPN_CD_11             
,EXTRN_COUPN_CD_12             
,EXTRN_COUPN_CD_13             
,EXTRN_COUPN_CD_14             
,EXTRN_COUPN_CD_15             
,EXTRN_COUPN_CD_16             
,EXTRN_COUPN_CD_17             
,EXTRN_COUPN_CD_18             
,EXTRN_COUPN_CD_19             
,EXTRN_COUPN_CD_20             
,EXTRN_COUPN_CD_21             
,EXTRN_COUPN_CD_22             
,EXTRN_COUPN_CD_23             
,EXTRN_COUPN_CD_24             
,EXTRN_COUPN_CD_25             
,EXTRN_COUPN_CD_26             
,EXTRN_COUPN_CD_27             
,EXTRN_COUPN_CD_28             
,EXTRN_COUPN_CD_29             
,EXTRN_COUPN_CD_30             
,EXTRN_COUPN_CD_31             
,EXTRN_COUPN_CD_32             
,EXTRN_COUPN_CD_33             
,EXTRN_COUPN_CD_34             
,EXTRN_COUPN_CD_35             
,EXTRN_COUPN_CD_36             
,EXTRN_COUPN_CD_37             
,EXTRN_COUPN_CD_38             
,EXTRN_COUPN_CD_39             
,EXTRN_COUPN_CD_40             
)
SELECT
    T1.COMMUNICATION_ID              
    ,T1.COMM_PLAN_ID                  
    ,T1.HSHLD_PRSNA_ID                
    ,T1.MATCHD_CNSMR_PRSNA_ID         
    ,T1.REGIS_PRSNA_ID                
    ,T1.SELECTION_DTTM                
    ,T1.SELECTION_GROUP_ORD           
    ,T1.STEP_ID                       
    ,T1.STEP_DTTM                     
    ,T1.MESSAGE_ID                    
    ,T1.LEAD_KEY_ID                   
    ,NULL AS LEAD_KEY_SK                   
    ,NULL AS EXT_LEAD_KEY 
    ,T2.LEGAL_ENT_NBR
    ,EXTRN_COUPN_CD_1              
    ,EXTRN_COUPN_CD_2              
    ,EXTRN_COUPN_CD_3              
    ,EXTRN_COUPN_CD_4              
    ,EXTRN_COUPN_CD_5              
    ,EXTRN_COUPN_CD_6              
    ,EXTRN_COUPN_CD_7              
    ,EXTRN_COUPN_CD_8              
    ,EXTRN_COUPN_CD_9              
    ,EXTRN_COUPN_CD_10             
    ,EXTRN_COUPN_CD_11             
    ,EXTRN_COUPN_CD_12             
    ,EXTRN_COUPN_CD_13             
    ,EXTRN_COUPN_CD_14             
    ,EXTRN_COUPN_CD_15             
    ,EXTRN_COUPN_CD_16             
    ,EXTRN_COUPN_CD_17             
    ,EXTRN_COUPN_CD_18             
    ,EXTRN_COUPN_CD_19             
    ,EXTRN_COUPN_CD_20             
    ,EXTRN_COUPN_CD_21             
    ,EXTRN_COUPN_CD_22             
    ,EXTRN_COUPN_CD_23             
    ,EXTRN_COUPN_CD_24             
    ,EXTRN_COUPN_CD_25             
    ,EXTRN_COUPN_CD_26             
    ,EXTRN_COUPN_CD_27             
    ,EXTRN_COUPN_CD_28             
    ,EXTRN_COUPN_CD_29             
    ,EXTRN_COUPN_CD_30             
    ,EXTRN_COUPN_CD_31             
    ,EXTRN_COUPN_CD_32             
    ,EXTRN_COUPN_CD_33             
    ,EXTRN_COUPN_CD_34             
    ,EXTRN_COUPN_CD_35             
    ,EXTRN_COUPN_CD_36             
    ,EXTRN_COUPN_CD_37             
    ,EXTRN_COUPN_CD_38             
    ,EXTRN_COUPN_CD_39             
    ,EXTRN_COUPN_CD_40        
FROM
    "@LeadDatabase".LH_LEAD_KEY_HISTORY T1
JOIN
(
SELECT
     TRM_LEAD_KEY
    ,LEGAL_ENT_NBR
    ,MAX(CASE WHEN Row_Num=1 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_1
    ,MAX(CASE WHEN Row_Num=2 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_2
    ,MAX(CASE WHEN Row_Num=3 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_3    
    ,MAX(CASE WHEN Row_Num=4 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_4
    ,MAX(CASE WHEN Row_Num=5 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_5
    ,MAX(CASE WHEN Row_Num=6 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_6    
    ,MAX(CASE WHEN Row_Num=7 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_7 
    ,MAX(CASE WHEN Row_Num=8 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_8 
    ,MAX(CASE WHEN Row_Num=9 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_9 
    ,MAX(CASE WHEN Row_Num=10 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_10 
    ,MAX(CASE WHEN Row_Num=11 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_11
    ,MAX(CASE WHEN Row_Num=12 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_12 
    ,MAX(CASE WHEN Row_Num=13 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_13 
    ,MAX(CASE WHEN Row_Num=14 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_14 
    ,MAX(CASE WHEN Row_Num=15 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_15 
    ,MAX(CASE WHEN Row_Num=16 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_16 
    ,MAX(CASE WHEN Row_Num=17 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_17 
    ,MAX(CASE WHEN Row_Num=18 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_18 
    ,MAX(CASE WHEN Row_Num=19 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_19 
    ,MAX(CASE WHEN Row_Num=20 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_20 
    ,MAX(CASE WHEN Row_Num=21 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_21 
    ,MAX(CASE WHEN Row_Num=22 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_22 
    ,MAX(CASE WHEN Row_Num=23 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_23 
    ,MAX(CASE WHEN Row_Num=24 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_24 
    ,MAX(CASE WHEN Row_Num=25 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_25 
    ,MAX(CASE WHEN Row_Num=26 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_26    
    ,MAX(CASE WHEN Row_Num=27 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_27 
    ,MAX(CASE WHEN Row_Num=28 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_28 
    ,MAX(CASE WHEN Row_Num=29 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_29 
    ,MAX(CASE WHEN Row_Num=30 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_30 
    ,MAX(CASE WHEN Row_Num=31 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_31 
    ,MAX(CASE WHEN Row_Num=32 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_32 
    ,MAX(CASE WHEN Row_Num=33 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_33 
    ,MAX(CASE WHEN Row_Num=34 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_34 
    ,MAX(CASE WHEN Row_Num=35 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_35 
    ,MAX(CASE WHEN Row_Num=36 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_36     
    ,MAX(CASE WHEN Row_Num=37 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_37 
    ,MAX(CASE WHEN Row_Num=38 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_38 
    ,MAX(CASE WHEN Row_Num=39 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_39 
    ,MAX(CASE WHEN Row_Num=40 THEN EXTRN_COUPN_CD END) AS EXTRN_COUPN_CD_40     
FROM
(
SELECT
    TRM_LEAD_KEY
    ,LEGAL_ENT_NBR
    ,EXTRN_COUPN_CD
    ,ROW_NUMBER() OVER (PARTITION BY TRM_LEAD_KEY ORDER BY INCTV_NBR) AS Row_Num
FROM
    "@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId
) k1
GROUP BY 1,2
) T2
ON
    t1.lead_key_id=t2.trm_lead_key
JOIN
    "@LeadDatabase".LH_RUN_HISTORY t3
ON
    t1.Step_Dttm=t3.Process_Dttm
	AND T1.Communication_Id=T3.Communication_Id	
WHERE
	t3.Run_Id='@RunId'	
;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;


/*DELETE LOCKS*/
LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".EX_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
LOCK TABLE "@LeadDatabase".LH_RUN_HISTORY FOR ACCESS
LOCK TABLE "@CoreDatabase".CM_COMM_PLAN_STEP FOR ACCESS
DELETE FROM "@CoreDatabase".CR_COMPONENT_LOCK
WHERE	
	(Component_Id
	,Component_Type_Cd
	,Job_History_Id
	) IN
(	
SELECT
    Key1_Val AS INCTV_NBR_Lock
    ,12             
    ,'@JobHistoryId'              
FROM
    (SELECT distinct s1.communication_id,s1.Comm_Plan_Id,s1.collateral_id,s1.step_id,s2.Run_Id from "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL s1
	JOIN "@LeadDatabase".LH_RUN_HISTORY s2 ON s1.communication_id=s2.COMMUNICATION_ID
	JOIN "@CoreDatabase".CM_COMM_PLAN_STEP s3 ON s1.Step_Id=s3.Step_Id and s1.Comm_Plan_Id=s3.Comm_Plan_Id AND s3.First_Step_Ind=0) t1
JOIN
    "@CoreDatabase".EX_COLLATERAL t2
ON
    t1.Collateral_Id=t2.Collateral_Id
JOIN
    "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE t3
ON
    t2.CNTNT_INCTV_ID=t3.Selection_Plan_Id	
WHERE
    t3.Schema_Element_Id=94
    AND t3.key2_val='CPY'
    AND t3.Key3_Val='I'
    AND t1.Run_Id='@RunId'
)
;    
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

/*DROP WORKING TABLES*/

DROP TABLE "@LeadDatabase".WK_COUPON_NUMBERS@WorkingPartitionId;
DROP TABLE "@LeadDatabase".WK_LEADS_NUMBERS@WorkingPartitionId;
DROP TABLE "@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId;

.QUIT 0;

.LABEL SKIP_PROCESS;          
.QUIT 0;

.LABEL ERROR_END;
.QUIT ERRORCODE;
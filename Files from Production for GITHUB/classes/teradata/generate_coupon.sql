/*
Check if the coupon process should be run 
*/

/*check unique coupon*/

LOCK ROW FOR ACCESS
SELECT
    1
FROM
    (SELECT DISTINCT communication_id,comm_plan_id,collateral_id,step_id FROM "TRM_META_DB".CM_COMM_PACKAGE_COLLATERAL) t1
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
	AND T1.Comm_Plan_Id=T4.Comm_Plan_Id
	AND T4.First_Step_Ind=1	
WHERE
    t3.Schema_Element_Id=94
    AND t3.key2_val='CPY'
    AND t3.Key3_Val='I'
    AND t1.Communication_Id='@ObjectId'
;    

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.IF ACTIVITYCOUNT != 0 THEN .GOTO UNIQUE_COUPONS;

/*check non-unique coupon*/
LOCK ROW FOR ACCESS
SELECT
    1
FROM
    (SELECT DISTINCT communication_id,comm_plan_id,collateral_id,step_id FROM "TRM_META_DB".CM_COMM_PACKAGE_COLLATERAL) t1
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
	AND T4.First_Step_Ind=1	
WHERE
    t3.Schema_Element_Id=94
    AND t3.key2_val='CPN'
    AND t3.Key3_Val='I'
    AND t1.Communication_Id='@ObjectId'
;    

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.IF ACTIVITYCOUNT = 0 THEN .GOTO SKIP_PROCESS;

/*NON_UNIQUE PROCESS*/
.LABEL NON_UNIQUE_COUPON;

CALL TRM_CSP_USR.CSP_COUPON_MAIN(1,'@RunId',@WorkingPartitionId,Session_Id);

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.QUIT 0;

.LABEL UNIQUE_COUPONS;
/*CREATE TABLE "@CoreDatabase".COUPON_EMAIL
(
 Communication_Id VARCHAR(12)
 ,Run_Id VARCHAR(12)
 ,Step_Dttm TIMESTAMP(6)
 ,Email_Type_Cd BYTEINT
 ,INCTV_NBR INTEGER
 ,No_Coupons BIGINT
 ,No_Leads BIGINT
 ,Locking_Communication_Id VARCHAR(12)
 ,Locking_Run_Id VARCHAR(12)
 ,Step_Id VARCHAR(12)
 ) PRIMARY INDEX(Run_Id);
*/



/*LOCK THE PROCESS*/
/*BEGIN TRANSACTION;
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
*/
DELETE FROM "@CoreDatabase".COUPON_EMAIL
WHERE
	Run_Id='@RunId';

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

DROP TABLE COUPON_COMPONENT_LOCK@WorkingPartitionId;

LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".EX_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
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
    ,'@RunId' AS Run_Id
    ,1 AS EMAIL_TYPE_CD
    ,t6.Communication_Id AS Blocking_Communication_Id
    ,t5.Run_Id AS Blocking_Run_Id
FROM
    (SELECT DISTINCT communication_id,comm_plan_id,collateral_id,step_id FROM "TRM_META_DB".CM_COMM_PACKAGE_COLLATERAL) t1
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
WHERE
    t3.Schema_Element_Id=94
    AND t3.key2_val='CPY'
    AND t3.Key3_Val='I'
    AND t1.Communication_Id='@ObjectId'
) WITH DATA PRIMARY INDEX (INCTV_NBR_Lock)
ON COMMIT PRESERVE ROWS
;  

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

SELECT 1 FROM COUPON_COMPONENT_LOCK@WorkingPartitionId WHERE Blocking_Run_Id IS NOT NULL;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.IF ACTIVITYCOUNT != 0 THEN .GOTO FAIL_LOCK;


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
	
	
/*END TRANSACTION;
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
*/
/*
Check if enough coupons are available
*/
DROP TABLE CHECK_COUPON_NUMBER@WorkingPartitionId;


LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
LOCK TABLE "@CoreDatabase".ex_collateral FOR ACCESS
LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL FOR ACCESS
CREATE VOLATILE TABLE CHECK_COUPON_NUMBER@WorkingPartitionId
AS
(SELECT
    s2.Communication_Id
    ,'@RunId' AS Run_Id
    ,2 AS Email_Type_Cd
    ,s1.INCTV_NBR
    ,zeroifnull(#coupons/count(*) over (partition by s1.INCTV_NBR)) AS No_Coupons --if one coupon is used in multiple collaterals then we are using the average number	
    ,zeroifnull(#leads) AS No_Leads
FROM    
(
SELECT 
    t4.Communication_Id
    ,t4.Collateral_Id
    ,t2.Key1_Val AS INCTV_NBR
    ,COUNT(T1.INCTV_NBR) #coupons
FROM 
	TRM_VIEWS_DB.EXTRN_COUPN_V T1
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
    (SELECT distinct s1.communication_id,s1.Comm_Plan_Id,s1.collateral_id,s1.step_id from "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL s1
	JOIN "@CoreDatabase".CM_COMM_PLAN_STEP s3 ON s1.Step_Id=s3.Step_Id and s1.Comm_Plan_Id=s3.Comm_Plan_Id AND s3.First_Step_Ind=1) t4
ON
    t3.Collateral_Id=t4.Collateral_Id	
WHERE
    t4.Communication_Id='@ObjectId'
	AND t2.Schema_Element_Id=94
GROUP BY 1,2,3
) S1
JOIN
(
SELECT 
    Communication_Id
    ,Collateral_Id
    ,COUNT(*) #leads 
FROM 
    "@LeadDatabase".WK_COLLATERAL_HISTORY@WorkingPartitionId
GROUP BY 1,2    
 ) S2
 ON
    S1.Communication_Id=S2.Communication_Id
    AND S1.Collateral_Id=S2.Collateral_Id
) WITH DATA PRIMARY INDEX (INCTV_NBR)
ON COMMIT PRESERVE ROWS
;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

SELECT 1 FROM CHECK_COUPON_NUMBER@WorkingPartitionId WHERE No_Coupons<No_Leads;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.IF ACTIVITYCOUNT != 0 THEN .GOTO NOT_ENOUGH_COUPONS;

.ASSIGN_UNIQUE_COUPONS;

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
LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE FOR ACCESS
INSERT INTO "@LeadDatabase".WK_COUPON_NUMBERS@WorkingPartitionId
SELECT 
    t4.Communication_Id
    ,t4.Collateral_Id
    ,t1.INCTV_NBR
    ,t1.EXTRN_COUPN_CD
    ,ROW_NUMBER() OVER (PARTITION BY t4.Communication_Id,t4.Collateral_Id,t1.INCTV_NBR ORDER BY 1) AS Coupon_Number
    ,t1.MKTNG_PGM_NBR
    ,t1.LEGAL_ENT_NBR 
    ,t1.EXTRN_COUPN_DATA_SRCE_NBR
FROM 
	TRM_VIEWS_DB.EXTRN_COUPN_V T1
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
    (SELECT distinct s1.communication_id,s1.Comm_Plan_Id,s1.collateral_id,s1.step_id from "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL s1
	JOIN "@CoreDatabase".CM_COMM_PLAN_STEP s3 ON s1.Step_Id=s3.Step_Id and s1.Comm_Plan_Id=s3.Comm_Plan_Id AND s3.First_Step_Ind=1) t4
ON
    t3.Collateral_Id=t4.Collateral_Id
WHERE
    t4.Communication_Id='@ObjectId'
;    

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

LOCK TABLE "@CoreDatabase".ex_collateral FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_LOGICAL_SEGMENT FOR ACCESS
INSERT INTO "@LeadDatabase".WK_LEADS_NUMBERS@WorkingPartitionId
SELECT 
    t1.Communication_Id
    ,T1.Collateral_Id
    ,t4.Key1_Val AS INCTV_NBR
    ,t2.Lead_Key_Id
    ,t1.REGIS_PRSNA_ID
    ,'@RunId'
	,ROW_NUMBER() OVER (PARTITION BY t1.Communication_Id,T1.Collateral_Id,t4.Key1_Val ORDER BY 1) AS Lead_Number
FROM 
	"@LeadDatabase".WK_COLLATERAL_HISTORY@WorkingPartitionId t1
JOIN
    "@LeadDatabase".WK_LEAD_KEY_HISTORY@WorkingPartitionId  T2
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
    "@CoreDatabase".ex_collateral T3
ON
    t1.Collateral_Id=t3.Collateral_Id
JOIN
    "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE t4
ON
    t3.CNTNT_INCTV_ID=t4.Selection_Plan_Id
    AND t4.Schema_Element_Id=94
    AND key2_val='CPY'
    AND Key3_Val='I'    
WHERE
    t1.Communication_Id='@ObjectId'
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
    "@LeadDatabase".WK_LEAD_KEY_HISTORY@WorkingPartitionId T1
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
;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;


/*DELETE LOCKS*/
LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".EX_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
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
    (SELECT distinct communication_id,comm_plan_id,collateral_id,step_id from "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL) t1
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
    AND t1.Communication_Id='@ObjectId'
)
;    
.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

/*DROP WORKING TABLES*/

DROP TABLE "@LeadDatabase".WK_COUPON_NUMBERS@WorkingPartitionId;
DROP TABLE "@LeadDatabase".WK_LEADS_NUMBERS@WorkingPartitionId;
DROP TABLE "@LeadDatabase".WK_EXTRN_COUPN_ASSIGN@WorkingPartitionId;

.QUIT 0;

.LABEL FAIL_LOCK;

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
FROM	
	COUPON_COMPONENT_LOCK@WorkingPartitionId
WHERE
	Blocking_Run_Id IS NOT NULL
;	

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.QUIT 0;

.LABEL NOT_ENOUGH_COUPONS;          

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
FROM	
	CHECK_COUPON_NUMBER@WorkingPartitionId
WHERE 
	No_Coupons<No_Leads;	
;	

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;

LOCK TABLE "@CoreDatabase".CM_COMM_PACKAGE_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".EX_COLLATERAL FOR ACCESS
LOCK TABLE "@CoreDatabase".SM_SCHEMA_ELEMENT_VALUE FOR ACCESS
DELETE FROM "@CoreDatabase".CR_COMPONENT_LOCK
WHERE	
	(Component_Id
	,Component_Type_Cd
	,Job_History_Id) IN
(	
SELECT
    Key1_Val AS INCTV_NBR_Lock
    ,12             
    ,'@JobHistoryId'              
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
WHERE
    t3.Schema_Element_Id=94
    AND t3.key2_val='CPY'
    AND t3.Key3_Val='I'
    AND t1.Communication_Id='@ObjectId'
)
;

.IF ERRORCODE != 0 THEN .GOTO ERROR_END;
.QUIT 0;

.LABEL SKIP_PROCESS;          
.QUIT 0;

.LABEL ERROR_END;
.QUIT ERRORCODE;
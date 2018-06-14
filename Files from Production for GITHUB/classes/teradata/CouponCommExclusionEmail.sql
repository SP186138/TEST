LOCK ROW ACCESS
SELECT
    DISTINCT
    CASE Email_Type_Cd
    WHEN 1 THEN 'Step '|| t7.Name || '(Id: '||t7.Step_Id||') of '||'communication '|| t2.NAME || '(Id: '||t2.Communication_Id||') is blocked by the '|| t3.NAME || '(Id: '||t3.Communication_Id||') communication.'
    ||' It was excluded from processing.'
    ||' Next attempt will be made during the next Intrday Batch job run.'	
    WHEN 2 THEN 'Not enough coupons available for Incentive: '|| TRIM(t1.INCTV_NBR) || ', Communication '|| t2.NAME || '(Id: '||t2.Communication_Id||')'
	||', Step '|| t7.NAME || '(Id: '||t7.Step_Id||')'
	||'. It was excluded from processing'
    ||'. Number of available coupons: '|| TRIM(t1.No_Coupons) ||', number of leads: ' || TRIM(t1.No_Leads)
	||'. Please load more coupons for the next Intrday Batch job run.'
    END AS Body
    ,t5.Email AS To_Address
    ,'RB Coupon Assignment Failure, Communication '|| t2.NAME  AS Subject
    ,NULL AS CC_Address 
FROM    
    "@CoreDatabase".COUPON_EMAIL t1
JOIN
    "@CoreDatabase".CM_COMMUNICATION t2
ON
    t1.Communication_Id=t2.Communication_Id
LEFT JOIN
    "@CoreDatabase".CM_COMMUNICATION t3
ON
    t1.Locking_Communication_Id=t3.Communication_Id
JOIN
    "@CoreDatabase".CR_JOB_HISTORY t4
ON
    t1.Run_Id=t4.Run_Id
JOIN
    "@CoreDatabase".CR_USER t5
ON
    t2.Update_User=t5.User_Name
LEFT JOIN
	"@CoreDatabase".CM_STEP t7
ON	
	t1.Step_Id=t7.Step_Id	
WHERE
    t1.Run_Id='@RunId'
ORDER BY t1.INCTV_NBR	
;
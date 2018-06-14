LOCK ROW ACCESS
SELECT
    DISTINCT
    CASE Email_Type_Cd
    WHEN 1 THEN 'Communication '|| t2.NAME || '(Id: '||t2.Communication_Id||') is blocked by the '|| t3.NAME || '(Id: '||t3.Communication_Id||') communication.'
    ||' Please wait until the first communication completes successfully.'
    WHEN 2 THEN 'Not enough coupons available for Incentive: '|| TRIM(t1.INCTV_NBR) || ', Communication '|| t2.NAME || '(Id: '||t2.Communication_Id||')'
    ||'. Number of available coupons: '|| TRIM(t1.No_Coupons) ||', number of leads: ' || TRIM(t1.No_Leads)
    ||'. Please do one of the following:'
	|| x'000A' || 'a) limit the number of the consumers in the campaign, abandon the failed job and rerun the campaign '
	|| x'000A' || 'b) load more coupons and resume the failed job in RB.'
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
    t4.Update_User=t5.User_Name
WHERE
    t1.Run_Id='@RunId'
ORDER BY t1.INCTV_NBR	
;
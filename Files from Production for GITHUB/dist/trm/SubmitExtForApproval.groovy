import org.apache.commons.lang.StringUtils;
import groovy.sql.Sql;


//  check for previous submittals/approvals
              
	trmLogger.info("Extract Format: " + trmComponent.id + " submitted for approval by " + trmCurrentUser.userName);
       	def wfMsgRow = trmUtilities.executeQuery("SELECT Approval_Cd, Approval_Req_User FROM EX_EXTRACT_FORMAT WHERE EXTRACT_FORMAT_ID = '" + trmComponent.id + "'");         
	def approvalCd = 0;
	def insertRow = true;
	if (wfMsgRow[0] != null) {
		insertRow = false;
	     	approvalCd = wfMsgRow[0].get("Approval_Cd");
//		def approvalReqUserName = wfMsgRow[0].get("Approval_Req_User");
        

		switch (approvalCd) {
     			case 1: 
	 			requestUserInfo = trmUtilities.executeQuery("SELECT u.USER_ID, u.EMAIL, u.FIRST_NAME || ' ' || u.LAST_NAME AS DISPLAY_NAME FROM CR_USER u INNER JOIN EX_EXTRACT_FORMAT ex ON ex.approval_Req_User = u.USER_NAME WHERE ex.EXTRACT_FORMAT_ID = '${trmComponent.id}'");
				requestUserInfo = trmUtilities.executeQuery("SELECT u.EMAIL, u.FIRST_NAME || ' ' || u.LAST_NAME AS DISPLAY_NAME FROM CR_USER u INNER JOIN EX_EXTRACT_FORMAT ex ON ex.approval_Req_User = u.USER_NAME WHERE ex.EXTRACT_FORMAT_ID = '${trmComponent.id}'");
        			requestUserName = requestUserInfo[0].get("DISPLAY_NAME");
				trmLogger.info("InfoBar message: Extract Format: " + trmComponent.id + " has already been Submitted for Approval by " + requestUserName  + ". No Notification was sent");
     				trmInfoBar.addWarningMessage("Extract Format has already been Submitted for Approval by " + requestUserName  + ". No Notification was sent");
				break;
		
			case 2: 
     				trmLogger.info("Extract Format: " + trmComponent.id + " has already been Approved. No Notification was sent");
     				trmInfoBar.addWarningMessage("Extract Format has already been Approved. No Notification was sent");
				break;
		
		}
	}


// if not previously submitted, do it
	if (approvalCd == 0) {

//		First, check to see if the folder has group security.  If so, use this group

		def folderInfo = trmUtilities.executeQuery("SELECT Folder_Id FROM CR_FOLDER_ENTRY WHERE Entity_Id = '" + trmComponent.id + "'");
		trmLogger.info("SQL to find Extract Format's folder: SELECT Folder_Id FROM CR_FOLDER_ENTRY WHERE Entity_Id = '" + trmComponent.id + "'");
		def folderId = folderInfo[0].get("Folder_Id");
		def marketGroupInfo = trmUtilities.executeQuery("SELECT Group_Id FROM CR_GROUP_FOLDER WHERE Folder_Id = '" + folderId + "'");
		trmLogger.info("SQL to find group for folder: SELECT Group_Id FROM CR_GROUP_FOLDER WHERE Folder_Id = '" + folderId + "'");
		if (marketGroupInfo[0] == null) {
		// If the folder has no group security, find the marketing program group erlated to this user.

	 		requestUserInfo = trmUtilities.executeQuery("SELECT USER_ID FROM CR_USER WHERE USER_NAME = '" + trmCurrentUser.username + "' " );
			userId = requestUserInfo[0].get("User_Id");
			marketGroupInfo = trmUtilities.executeQuery("SELECT Group_Id FROM TRM_META_DB.CR_GROUP_USER WHERE User_Id = '" + userId + "' AND " +
								"Group_Id IN (SELECT Group_Id FROM TRM_META_DB.EX_MKTNG_PGM)");
			trmLogger.info("SQL to find Marketing Program Group for user: SELECT Group_Id FROM TRM_META_DB.CR_GROUP_USER WHERE User_Id = '" + userId + "' AND " +
								"Group_Id IN (SELECT Group_Id FROM TRM_META_DB.EX_MKTNG_PGM)");
		}

		def approverFound = false;
		def approverNames = ""
	
		if (marketGroupInfo[0] != null) {
		// if we've found a marketing program group, find the approvers in this group
			def marketGroupId = marketGroupInfo[0].get("Group_Id"); // there should be only one group

			def dateTime = Calendar.getInstance();
			def currentTimestamp = String.format('%tm-%<td-%<tY %<tT', dateTime);
			def currentDate = String.format('%tY-%<tm-%<td', dateTime);

			def fromEmail = trmCurrentUser.email;
			def text = "Extract Format " + trmComponent.link + " has been submitted by " + trmCurrentUser.displayname + " for your approval.<BR><BR>";
		     	def subject = "Extract Format " + trmComponent.name  + " has been submitted for approval.";


//			def approverList = trmUtilities.executeQuery("SELECT User_Name, First_Name || ' ' || Last_Name as FullName, Email " +
			def approverListString = "SELECT DISTINCT First_Name || ' ' || Last_Name as FullName, Email " +
                	                     	"FROM CR_USER WHERE User_Id IN (SELECT User_Id FROM CR_GROUP_USER " +
						"WHERE Group_Id = 'PGAPPRV00001') AND User_Id IN (SELECT User_Id FROM CR_GROUP_USER " + 
						"WHERE Group_Id = '" + marketGroupId + "')";
			def approverList = trmUtilities.executeQuery(approverListString);
			trmLogger.info("SQL to find approvers for group: " + approverListString);



			approverList.each() {

				def toEmail = it.Email;
				if (toEmail != null) {
					trmUtilities.sendEmail(fromEmail,toEmail,text,subject);

					approverFound = true;
					approverNames = approverNames + it.FullName + ", ";
				} else {
					trmLogger.info("No valid email for user: " + it.User_Name);
				}
			}
		} else {
   			trmLogger.error("Extract Format: " + trmComponent.id + " Is located in a folder not corresponding to any Marketing Program.  System cannot has already been Approved. No Notification was sent");
     			trmInfoBar.addWarningMessage("Extract Format has already been Approved. No Notification was sent");
		}


		if (approverFound) {
			if (insertRow) {
		     		def insertString = "INSERT INTO EX_EXTRACT_FORMAT " +
					"(EXTRACT_FORMAT_Id, " +
					" Approval_Cd, " +
					" Approval_Req_User, " + 
					" Approval_Req_Dttm" + 
					" ) VALUES " +
					"('" + trmComponent.id + "', " +
					" 1, " +
					" '" + trmCurrentUser.username + "', " +
					" CURRENT_TIMESTAMP(6)); ";         

		     		def wfMsgRow2 = trmUtilities.executeQuery(insertString);
				trmLogger.info("SQL to insert record to EX_EXTRACT_FORMAT: " + insertString);
			} else {
		        	def updateString = "UPDATE DBATRM6.EX_EXTRACT_FORMAT SET Approval_Cd = 1, " +
 					"Approval_Req_User = '" + trmCurrentUser.username + "', " +
					"Approval_Req_Dttm = CURRENT_TIMESTAMP(6) " + 
 					" WHERE EXTRACT_FORMAT_ID = '" + trmComponent.id + "'";         
		        	def wfMsgRow3 = trmUtilities.executeQuery(updateString);
				trmLogger.info("SQL to update record in EX_EXTRACT_FORMAT: " + insertString);
			}

	     		trmInfoBar.addInfoMessage("Extract Format has been Submitted for Approval to " + approverNames + ".");
	     		trmLogger.info("Extract Format has been Submitted for Approval to " + approverNames + ".");

		} else {
			// if no user, or no email address available, then fail

	     		trmLogger.warning("No valid approvers were found.  No notifications were sent.");
	     		trmInfoBar.addErrorMessage("No valid approvers were found.  No notifications were sent.");

		}




	}



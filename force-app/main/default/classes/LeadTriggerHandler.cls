/*
 * The `LeadTriggerHandler` class contains methods designed to handle various business requirements around
 * the Lead object in Salesforce. This includes functionality like normalizing the Title field of a lead, 
 * automatically scoring leads based on certain criteria, and auto-converting leads when certain conditions are met.
 * - Create a test class for `LeadTriggerHandler` to ensure all methods work as expected.
 * - Update the LeadTrigger class to call the `LeadTriggerHandler` methods as needed.
 *
 * Students should note:
 * - This class may contain intentional errors that need to be fixed for proper functionality.
 * - Create a corresponding test class for `LeadTriggerHandler` to ensure all methods work as expected.
 *   Both positive and negative test cases should be considered.
 *
 * Documentation on Lead conversion and Test Classes can be found here:
 * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_dml_convertLead.htm
 * https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_test.htm
 */
public with sharing class LeadTriggerHandler {
	/* 
	 * Question 1
	 * Requirement Lead Title Normalization - handleTitleNormalization
	 * Occasionally, users input Titles in a variety of ways. Streamline these Titles for consistency:
	 *
	 * Criteria:
	 * - If the Title contains terms such as 'vp', 'v.p.', or 'vice president',
	 *   change the Title to 'Vice President'.
	 * - If the Title contains terms like 'mgr', 'manage', or 'head of department',
	 *   change the Title to 'Manager'.
	 * - Should the Title include words like 'exec', 'chief', or 'head',
	 *   change the Title to 'Executive'.
	 * - If the Title contains terms like 'assist', 'deputy', or 'jr',
	 *   change the Title to 'Assistant'.
	 */
	public static void handleTitleNormalization(List<Lead> leadsToNormalize) {
		if (leadsToNormalize ==null || leadsToNormalize.isEmpty()) {
			return;
		}

		for (Lead ld : leadsToNormalize) {
			if (ld.Title == null) {
				continue;
			}

			if (ld.Title.containsIgnoreCase('vp') || ld.Title.containsIgnoreCase('v.p.') || ld.Title.containsIgnoreCase('vice president')) {
				ld.Title = 'Vice President';
			} else if (
				ld.Title.containsIgnoreCase('mgr') ||
				ld.Title.containsIgnoreCase('manage') ||
				ld.Title.containsIgnoreCase('head of department')
			) {
				ld.Title = 'Manager';
			} else if (ld.Title.containsIgnoreCase('exec') || ld.Title == 'chief' || ld.Title.containsIgnoreCase('head')) {
				ld.Title = 'Executive';
			} else if (ld.Title.containsIgnoreCase('assist') || ld.Title.containsIgnoreCase('deputy') || ld.Title == 'jr') {
				ld.Title = 'Assistant';
			}
		}
	}

	/* 
	 * Question 2
	 * Requirement Auto Lead Scoring - handleAutoLeadScoring
	 * Implement logic to automatically assign scores to leads based on specific criteria.
	 * 18 should be highest possible score a lead can have.
	 *
	 * Criteria:
	 * - If the lead source is from the website and an email exists, increment score by 3 points.
	 * - If the lead provides a phone number, increment score by 5 points.
	 * - If the lead belongs to the 'Technology' industry, increment score by another 10 points.
	 */
	public static void handleAutoLeadScoring(List<Lead> leadsToScore) {
		for (Lead ld : leadsToScore) {
			Integer score = 10;

			// Check and add points based on the specified conditions
			if (ld.LeadSource == 'Web' && ld.Email != null) {
				score += 3;
			}

			if (ld.Phone != null) {
				score += 5;
			}

			if (ld.Industry == 'Technology') {
				score += 10;
			}

			if (score > 18) {
				score = 18;
			}

			ld.Lead_Score__c = score; // Set the computed score back to the lead
		}
	}

	/* 
	 * Question 3
	 * Requirement Automatic Lead Conversion Based on Email Match - handleLeadAutoConvert
	 * Whenever a new Lead is created or an existing Lead's email address is updated,
	 * check for a matching Contact based on the email address. If a single matching
	 * Contact is identified, auto-convert the Lead.
	 * Use the Salesforce report Converted Lead to verify that the Lead was converted to the correct Contact.
	 *
	 * Criteria:
	 * - Monitor the "Email" field on the Lead object for creation or updates.
	 * - On Lead creation or email update, search the Contact object for records with the
	 *   same email address.
	 * - If a single matching Contact is identified:
	 *     - Auto-convert the Lead.
	 *     - Merge the Lead details with the existing Contact, ensuring that crucial
	 *       Contact information is preserved.
	 * - If multiple Contacts with the same email are found or no match is identified,
	 *   leave the Lead unconverted.
	 * 
	 * Hint: 
	 * - One of the errors is recursion related. Check if the lead is already converted or check if the email has changed/is null
	 * - One of the errors is map related. Make sure you are using the correct contact map key
	 */
	public static void handleLeadAutoConvert(List<Lead> leads) {
		Map<Id,String> leadToEmailMap = new Map<Id,String>();
		for (Lead lead : leads) {
			if (String.isNotBlank(lead.Email) && !lead.IsConverted) {
			leadToEmailMap.put(lead.Id, lead.Email);
			}
		}

		// Step 2: Find matching contacts based on email
		Map<String, Contact> emailToContactMap = new Map<String, Contact>();
		for (Contact c : [SELECT Id, Email, AccountId FROM Contact WHERE Email IN :leadToEmailMap.values()]) {
			if (!emailToContactMap.containsKey(c.Email)) {
				emailToContactMap.put(c.Email, c);
			} else {
				// If we found another contact with the same email, we don't auto-convert.
				// So we remove the email from the map.
				emailToContactMap.remove(c.Email);
			}
		}
		
		// Step 3: Auto-convert leads
		List<Lead> leadsToCheck = [SELECT Id, IsConverted FROM Lead WHERE Id IN :leadToEmailMap.keySet()];

		Map<Id, Lead> leadIdToLeadMap = new Map<Id, Lead>();
		for (Lead lead : leadsToCheck) {
			leadIdToLeadMap.put(lead.Id, lead);
		}

		List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();
		LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = TRUE LIMIT 1];
		for (Id leadId : leadToEmailMap.keySet()) {
            String leadEmail = leadToEmailMap.get(leadId);
			if (emailToContactMap.containsKey(leadEmail)) {
				Lead lead = leadIdToLeadMap.get(leadId);
				if (lead !=null && !lead.IsConverted) {
				Database.LeadConvert lc = new Database.LeadConvert();
				lc.setLeadId(leadId);
				lc.setContactId(emailToContactMap.get(leadEmail).Id); // Use existing Contact Id
				lc.setAccountId(emailToContactMap.get(leadEmail).AccountId); // Use existing Account Id
				lc.setDoNotCreateOpportunity(true); // Assuming we don't want to create an opportunity
				lc.setConvertedStatus(convertStatus.MasterLabel); // Set the converted status
				leadConverts.add(lc);
				}
			}
		}

		if (!leadConverts.isEmpty()) {
			List<Database.LeadConvertResult> lcrs = Database.convertLead(leadConverts);
		}
	}
}

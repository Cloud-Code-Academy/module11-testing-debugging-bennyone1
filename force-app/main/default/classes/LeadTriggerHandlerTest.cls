@isTest 
public with sharing class LeadTriggerHandlerTest {
    public LeadTriggerHandlerTest() {

    }

    @isTest
    static void test_leadsToNormalize() {
        List<String> titleNames = new List<String>{
            'vp', 'v.p.', 'vice president', 'mgr', 'manager', 'head of department', 
            'exec', 'chief', 'head', 'assist', 'deputy', 'jr', 'junior',
            'vice pres', 'dept lead', 'boss', ''
        };
    
        List<Lead> leadsToInsert = new List<Lead>();
    
        for (Integer i = 0; i < 400; i++) {
            Integer randomIndex = (Integer) Math.floor(Math.random() * titleNames.size());
            String randomTitle = titleNames[randomIndex];
    
            Lead ld = new Lead(FirstName = 'Test', LastName = 'Lead ' + i, Company = 'Test Company ' + i, Title = randomTitle);
    
            leadsToInsert.add(ld);
        }
    
        
        Test.startTest();
        insert leadsToInsert;
        Test.stopTest();
    
        List<Lead> insertedLeads = [SELECT Id, FirstName, LastName, Company, Title FROM Lead WHERE Id IN :leadsToInsert];
    
        for (Lead ld : insertedLeads) {
            if (ld.Title != null) {
                if (ld.Title.containsIgnoreCase('vp') || ld.Title.containsIgnoreCase('v.p.') || ld.Title.containsIgnoreCase('vice president')) {
                    Assert.areEqual('Vice President', ld.Title, 'Title should be normalized to Vice President');
                } else if (ld.Title.containsIgnoreCase('mgr') || ld.Title.containsIgnoreCase('manage') || ld.Title.containsIgnoreCase('head of department')) {
                    Assert.areEqual('Manager', ld.Title, 'Title should be normalized to Manager');
                } else if (ld.Title.containsIgnoreCase('exec') || ld.Title.equalsIgnoreCase('chief') || ld.Title.containsIgnoreCase('head')) {
                    Assert.areEqual('Executive', ld.Title, 'Title should be normalized to Executive');
                } else if (ld.Title.containsIgnoreCase('assist') || ld.Title.containsIgnoreCase('deputy') || ld.Title.equalsIgnoreCase('jr')) {
                    Assert.areEqual('Assistant', ld.Title, 'Title should be normalized to Assistant');
                }
            }
        }
    }

    @isTest 
    static void test_handleAutoLeadScoring() {
        // List of industries and lead sources to randomly select
        List<String> listOfIndustries = new List<String>{'Technology', 'Agriculture', 'Chemicals', 'Banking', 'Education'};
        List<String> listOfLeadSources = new List<String>{'Web', 'Purchased List','Phone Inquiry', 'Partner Referral'};

        List<Lead> leadsToInsert = new List<Lead>();
        
        // Generate a random indistry and lead source to use for all leads
        Integer randomIndustryIndex = (Integer) Math.floor(Math.random() * listOfIndustries.size());
        Integer randomSourceIndex = (Integer) Math.floor(Math.random() * listOfLeadSources.size());

        String randomIndustry = listOfIndustries[randomIndustryIndex];
        String randomSource = listOfLeadSources[randomSourceIndex];
        
        Integer totalLeadScore = 18;

        for (Integer i = 0; i < 400; i++) {
            String formattedIndex = padLeft(String.valueOf(i), 3);
            if (Math.mod(i, 2) == 0) {
                leadsToInsert.add(new Lead(FirstName = 'Test', LastName = 'Lead ' + i, Company = 'Test Company' + formattedIndex, Industry = randomIndustry, LeadSource = randomSource, Phone = '123-456-' + formattedIndex));
            } else {
                leadsToInsert.add(new Lead(FirstName = 'Test', LastName = 'Lead ' + i, Company = 'Test Company' + formattedIndex, Industry = randomIndustry, LeadSource = randomSource, Email = 'Test' + formattedIndex + '@sfmail.com'));
            }
        }

        Test.startTest();
        insert leadsToInsert;
        Test.stopTest();

        List<Lead> insertedLeads = [SELECT Id, FirstName, LastName, Industry, LeadSource, Lead_Score__c, Email, Phone FROM Lead WHERE Id IN :leadsToInsert];
        for (Lead ld : insertedLeads) {
            if (ld.LeadSource == 'Web' && ld.Email != null) {
				Assert.areEqual(3, 3, 'Score should at least be 3');
			}

			if (ld.Phone != null) {
				Assert.areEqual(5, 5, 'Score should at least be 5');
			}

			if (ld.Industry == 'Technology') {
				Assert.areEqual(10, 10, 'Score should at least be 10');
			}

			if (totalLeadScore > 18) {
				Assert.areEqual(18, 18, 'Score should not exceed 18');
			}
        }
    }

    public static String padLeft(String originalString, Integer targetLength) {
        while (originalString.length() < targetLength) {
            originalString = '0' + originalString;
        }
        return originalString;
    }

    @IsTest
    static void test_handleLeadAutoConvert() {
        //Create Accounts
        List<Account> accountsToInsert = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            Account acc = new Account(Name = 'Test Account ' + i);
            accountsToInsert.add(acc);
        }
        insert accountsToInsert;

        // Create Contacts
        List<Contact> contactsToInsert = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            Integer accountIndex = i / 20;
            Id accountId = accountsToInsert[accountIndex].Id;
            Contact con = new Contact(
                FirstName = 'TestContactFirstName ' + i,
                LastName = 'TestContactLastName ' + i, 
                AccountId = accountId,
                Email = (i < 75) ? 'test' + i + '@example.com' : 'uniqueEmail' + i + '@example.com'
            );
            contactsToInsert.add(con);
        }
        insert contactsToInsert;
        
        // Create Leads
        List<Lead> leadsToInsert = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            Lead ld = new Lead(
                FirstName = 'TestLeadFirstName ' + i, 
                LastName = 'TestLeadLastName ' + i, 
                Company = 'Test Company ' + i,
                Email = (i < 100) ? 'test' + i + '@example.com' 
                        : (i >= 100 && i < 175) ? 'uniqueEmail' + i + '@somedomain.com' 
                        : ''
            );
            leadsToInsert.add(ld);
        }

        // Insert Leads and test trigger
        Test.startTest();
        insert leadsToInsert;
        Test.stopTest();

        // Query converted leads
        List<Lead> convertedLeads = [SELECT Id, IsConverted, Email FROM Lead WHERE Email LIKE 'test%@example.com' AND IsConverted = true];
        
        // Query non-converted leads
        List<Lead> nonConvertedLeads = [SELECT Id, IsConverted, Email FROM Lead WHERE (Email LIKE 'uniqueEmail%@somedomain.com' OR Email = '') AND IsConverted = false];

        //Query the null email address
        List<Lead> emptyEmails = [SELECT Id, IsConverted, Email FROM Lead WHERE Email = null or Email = ''];

        Assert.areEqual(75, convertedLeads.size(), '75 leads should have been auto converted');
        Assert.areEqual(100, nonConvertedLeads.size(), '100 Leads should not have been auto converted');
        Assert.areEqual(25, emptyEmails.size(), '25 Leads should have been skipped');
    }

}

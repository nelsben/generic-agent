/**
 * CustomerSummaryTestUsers: the test user every test that touches Customer Summary's own objects and fields runs as
 * (BE-54). Apex tests run as the user who deploys. In a new org that admin does not hold Customer_Summary_User yet
 * (README step 3 comes after the deploy), and the product reads and writes in user mode, so the new fields are
 * invisible to the deployer. The user made here is rolled back with the test and holds the product's two permission
 * sets, so a test no longer depends on who deploys.
 */
@IsTest
public with sharing class CustomerSummaryTestUsers {
    private static final List<String> PRODUCT_SETS = new List<String>{
        'Customer_Summary_Data_Access', 'Customer_Summary_Outcome_Access'
    };

    // system-context: test setup builds a user and its permission set assignments, which no rep could do for itself
    /**
     * A System Administrator (sees every record, as the deploying admin does) who holds the product's permission sets.
     * Run the test body as it: System.runAs(CustomerSummaryTestUsers.productUser()) { ... }.
     */
    public static User productUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' WITH SYSTEM_MODE LIMIT 1];
        String uniq = 'csu' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'csuser',
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Summary Test User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.summarytest'
        );
        // Setup objects (User, PermissionSetAssignment) in their own context, apart from the test's data.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert as system u;
            List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
            for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :PRODUCT_SETS WITH SYSTEM_MODE]) {
                assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
            }
            Assert.areEqual(PRODUCT_SETS.size(), assignments.size(), 'both product permission sets are in the org');
            insert as system assignments;
        }
        return u;
    }
}

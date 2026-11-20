// Loads demo data: FAQs, a customer account/contact and a few cases.
// Run with: sf apex run --file scripts/apex/sample-data.apex

List<FAQ__c> faqs = new List<FAQ__c>{
    new FAQ__c(Name = 'How do I reset my password?', Category__c = 'Account', Active__c = true,
        Answer__c = 'Go to the login page, click "Forgot password" and follow the link we email you. The link is valid for 24 hours.'),
    new FAQ__c(Name = 'How do I update my email address?', Category__c = 'Account', Active__c = true,
        Answer__c = 'Open My Profile, click Edit next to Email, enter the new address and confirm it from your inbox.'),
    new FAQ__c(Name = 'Why was I charged twice?', Category__c = 'Billing', Active__c = true,
        Answer__c = 'A second charge is usually a pending authorisation that drops off within 3 business days. If it is still there after that, open a case and attach your bank statement.'),
    new FAQ__c(Name = 'How do I download my invoice?', Category__c = 'Billing', Active__c = true,
        Answer__c = 'Go to Billing > Invoices and click the download icon next to the invoice you need.'),
    new FAQ__c(Name = 'Can I get a refund?', Category__c = 'Billing', Active__c = true,
        Answer__c = 'Refunds are available within 30 days of purchase. Open a case with your order number and we will process it within 5 business days.'),
    new FAQ__c(Name = 'The app crashes when I log in', Category__c = 'Technical', Active__c = true,
        Answer__c = 'Update to the latest app version, clear the app cache and restart your phone. If it still crashes, open a case with your phone model and app version.'),
    new FAQ__c(Name = 'I am not receiving notification emails', Category__c = 'Technical', Active__c = true,
        Answer__c = 'Check your spam folder and add support@example.com to your contacts. Notification settings are under My Profile > Notifications.'),
    new FAQ__c(Name = 'Where is my order?', Category__c = 'Shipping', Active__c = true,
        Answer__c = 'Use the tracking link in your shipping confirmation email. Orders usually arrive within 3 to 5 business days.'),
    new FAQ__c(Name = 'My package arrived damaged', Category__c = 'Shipping', Active__c = true,
        Answer__c = 'Sorry about that! Open a case with photos of the package and the item, and we will send a replacement.')
};
insert faqs;

Account acc = new Account(Name = 'Sunrise Retail Pvt Ltd');
insert acc;

Contact con = new Contact(FirstName = 'Priya', LastName = 'Sharma', Email = 'priya.sharma@example.com', AccountId = acc.Id);
insert con;

List<Case> cases = new List<Case>{
    new Case(Subject = 'Charged twice for November', Description = 'I see two charges of Rs 999 on my card.',
        Product_Category__c = 'Billing', Source_Channel__c = 'Portal', ContactId = con.Id, AccountId = acc.Id),
    new Case(Subject = 'App crashes on Android 15', Description = 'Crashes right after the splash screen.',
        Product_Category__c = 'Technical', Source_Channel__c = 'Portal', ContactId = con.Id, AccountId = acc.Id,
        Status = 'Waiting on Customer'),
    new Case(Subject = 'Damaged headphones', Description = 'The box was crushed.',
        Product_Category__c = 'Shipping', Source_Channel__c = 'AI Agent', ContactId = con.Id, AccountId = acc.Id)
};
insert cases;

insert new CaseComment(ParentId = cases[1].Id, IsPublished = true,
    CommentBody = 'Thanks for reporting this. Could you share your phone model and the app version?');

System.debug('Sample data created. Contact email for agent testing: ' + con.Email);

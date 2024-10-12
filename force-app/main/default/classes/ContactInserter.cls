public class ContactInserter {
    public Map<String, String> failedUpdates { get; private set; }

    public ContactInserter() {
        failedUpdates = new Map<String, String>();
    }

    public void insertContactsFromJson() {
        Organization orgInfo = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
        Boolean isSandbox = orgInfo.IsSandbox;
        StaticResource contactsResource = [SELECT Body FROM StaticResource WHERE Name = 'contact_json'];
        String jsonContent = contactsResource.Body.toString();
        List<Object> jsonData = (List<Object>) JSON.deserializeUntyped(jsonContent);
        List<Contact> contactsToInsert = new List<Contact>();
        List<Contact> contactsToUpdate = new List<Contact>();
        Map<String, Object> contactData = new Map<String, Object>();

        if (isSandbox == true) {
            for (Object obj : jsonData) {
                contactData = (Map<String, Object>) obj;
                Contact newContact = new Contact();
                newContact.FirstName = (String) contactData.get('FirstName');
                newContact.LastName = (String) contactData.get('LastName');
                newContact.Salutation = (String) contactData.get('Salutation');
                newContact.Email = (String) contactData.get('Email');
                contactsToInsert.add(newContact);
            }

            if (!contactsToInsert.isEmpty()) {
                try {
                    insert contactsToInsert;
                } catch (Exception e) {
                    System.debug('Exception message: ' + e.getMessage());
                }
            }
        } else {
            Set<String> emails = new Set<String>();
            for (Object obj : jsonData) {
                contactData = (Map<String, Object>) obj;
                String email = (String) contactData.get('Email');
                if (email != null) {
                    emails.add(email);
                }
            }

            List<Contact> existingContacts = [SELECT Id, Email FROM Contact WHERE Email IN :emails];
            for (Contact contact : existingContacts) {
                String currentEmail = contact.Email;
                Integer atIndex = currentEmail.indexOf('@');
                if (atIndex != -1) {
                    String maskedEmail = currentEmail.substring(0, atIndex) + '.test' + currentEmail.substring(atIndex);
                    contact.Email = maskedEmail;
                    contactsToUpdate.add(contact);
                }
            }

            if (!contactsToUpdate.isEmpty()) {
                Database.SaveResult[] updateResults = Database.update(contactsToUpdate, false);
                for (Integer i = 0; i < updateResults.size(); i++) {
                    if (!updateResults[i].isSuccess()) {
                        // Add the failed email and contact Id to the failedUpdates map
                        failedUpdates.put(contactsToUpdate[i].Id, contactsToUpdate[i].Email);
                    }
                }
                if (!failedUpdates.isEmpty()) {
                    sendFailedUpdatesEmail();
                }
            }
        }
    }

    private void sendFailedUpdatesEmail() {
        PageReference pdfPage = Page.FailedEmailReport;
        Blob pdfBlob = pdfPage.getContentAsPDF();

        // Prepare email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { 'kiransreeram8@live.com' });
        email.setSubject('Email failed to mask');
        email.setPlainTextBody('Find the details in the attachment in this mail.');

        // Attach PDF to email
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('Failed_Email_Report.pdf');
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

        // Send email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}
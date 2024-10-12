import { LightningElement, api, wire, track } from 'lwc';
import getChatGptResponse from '@salesforce/apex/ChatGptAPIService.getChatGptResponse';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import CASE_ID_FIELD from '@salesforce/schema/Case.Id';

export default class CaseInsights extends LightningElement {
    @api recordId; // Case record Id from the record page
    @track loading = false;
    @track response;

    handleClick() {
        this.loading = true;
        getChatGptResponse({ caseId: this.recordId })
            .then(result => {
                this.response = result;
                this.loading = false;
            })
            .catch(error => {
                this.loading = false;
                this.showToast('Error', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(event);
    }
}
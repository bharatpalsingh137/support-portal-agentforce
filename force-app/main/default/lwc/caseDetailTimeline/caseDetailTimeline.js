import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import CASE_CHANNEL from '@salesforce/messageChannel/CaseSelected__c';
import getCaseDetail from '@salesforce/apex/PortalCaseController.getCaseDetail';
import addComment from '@salesforce/apex/PortalCaseController.addComment';
import { errorMessage } from 'c/errorUtils';

const ICONS = {
    created: 'utility:case',
    comment: 'utility:comments',
    closed: 'utility:success'
};

const BADGES = {
    Closed: 'slds-badge slds-theme_success',
    Escalated: 'slds-badge slds-theme_error',
    'Waiting on Customer': 'slds-badge slds-theme_warning'
};

/**
 * Shows one case with its full history and lets the customer reply.
 * Works on a record page (recordId) or next to myCases via Lightning Message Service.
 */
export default class CaseDetailTimeline extends LightningElement {
    caseId;
    detail;
    error;
    isLoading = false;
    newComment = '';
    isSending = false;

    wiredDetailResult;
    subscription;

    @api
    get recordId() {
        return this.caseId;
    }
    set recordId(value) {
        this.caseId = value;
    }

    @wire(MessageContext)
    messageContext;

    @wire(getCaseDetail, { caseId: '$caseId' })
    wiredDetail(result) {
        this.wiredDetailResult = result;
        const { data, error } = result;
        if (data) {
            this.detail = data;
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.detail = undefined;
            this.error = errorMessage(error);
            this.isLoading = false;
        }
    }

    connectedCallback() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                CASE_CHANNEL,
                (message) => this.handleMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    handleMessage(message) {
        if (message && message.action === 'selected' && message.recordId !== this.caseId) {
            this.isLoading = true;
            this.newComment = '';
            this.caseId = message.recordId;
        }
    }

    get record() {
        return this.detail ? this.detail.record : undefined;
    }

    get cardTitle() {
        return this.record ? `Case ${this.record.CaseNumber}` : 'Case details';
    }

    get statusBadgeClass() {
        return (this.record && BADGES[this.record.Status]) || 'slds-badge';
    }

    get timelineItems() {
        if (!this.detail || !this.detail.timeline) {
            return [];
        }
        return this.detail.timeline.map((item) => ({
            ...item,
            iconName: ICONS[item.itemType] || 'utility:info',
            cssClass: `timeline-item ${item.isCustomer ? 'timeline-item_customer' : 'timeline-item_support'}`
        }));
    }

    get canComment() {
        return !!this.record && !this.record.IsClosed;
    }

    get hasFeedback() {
        return !!this.detail && this.detail.hasFeedback === true;
    }

    get showFeedbackForm() {
        return !!this.record && this.record.IsClosed && !this.hasFeedback;
    }

    get isSendDisabled() {
        return this.isSending || !this.newComment || !this.newComment.trim();
    }

    handleCommentChange(event) {
        this.newComment = event.detail.value;
    }

    async handleAddComment() {
        this.isSending = true;
        try {
            await addComment({ caseId: this.caseId, body: this.newComment });
            this.newComment = '';
            await refreshApex(this.wiredDetailResult);
            publish(this.messageContext, CASE_CHANNEL, { recordId: this.caseId, action: 'updated' });
            this.showToast('Reply sent', 'The support team has been notified.', 'success');
        } catch (error) {
            this.showToast('Could not send your reply', errorMessage(error), 'error');
        } finally {
            this.isSending = false;
        }
    }

    async handleFeedbackSubmitted() {
        await refreshApex(this.wiredDetailResult);
        publish(this.messageContext, CASE_CHANNEL, { recordId: this.caseId, action: 'updated' });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

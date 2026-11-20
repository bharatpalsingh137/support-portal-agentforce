import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { publish, subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import CASE_CHANNEL from '@salesforce/messageChannel/CaseSelected__c';
import getMyCases from '@salesforce/apex/PortalCaseController.getMyCases';
import { errorMessage } from 'c/errorUtils';

const STATUS_CLASSES = {
    New: 'slds-text-color_default',
    Working: 'slds-text-color_default',
    'Waiting on Customer': 'slds-text-color_error slds-text-title_bold',
    Escalated: 'slds-text-color_error',
    Closed: 'slds-text-color_success'
};

export const COLUMNS = [
    { label: 'Case #', fieldName: 'CaseNumber', initialWidth: 110 },
    { label: 'Subject', fieldName: 'Subject', wrapText: true },
    { label: 'Category', fieldName: 'Product_Category__c', initialWidth: 120 },
    {
        label: 'Status',
        fieldName: 'statusLabel',
        initialWidth: 170,
        cellAttributes: { class: { fieldName: 'statusClass' } }
    },
    { label: 'Priority', fieldName: 'Priority', initialWidth: 100 },
    {
        label: 'Last updated',
        fieldName: 'LastModifiedDate',
        type: 'date',
        initialWidth: 170,
        typeAttributes: { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }
    },
    { type: 'action', typeAttributes: { rowActions: [{ label: 'View details', name: 'view' }] } }
];

/**
 * Lists the current user's cases. Publishes the selected case on the CaseSelected
 * channel and refreshes itself when another component creates or updates a case.
 */
export default class MyCases extends LightningElement {
    columns = COLUMNS;
    statusFilter = 'Open';
    rows = [];
    error;
    isLoading = true;

    filterOptions = [
        { label: 'Open', value: 'Open' },
        { label: 'Closed', value: 'Closed' },
        { label: 'All', value: 'All' }
    ];

    wiredCasesResult;
    subscription;

    @wire(MessageContext)
    messageContext;

    @wire(getMyCases, { statusFilter: '$statusFilter' })
    wiredCases(result) {
        this.wiredCasesResult = result;
        const { data, error } = result;
        if (data) {
            this.rows = data.map((c) => ({
                ...c,
                statusLabel: c.Status === 'Waiting on Customer' ? 'Waiting on you' : c.Status,
                statusClass: STATUS_CLASSES[c.Status] || ''
            }));
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.rows = [];
            this.error = errorMessage(error);
            this.isLoading = false;
        }
    }

    get hasCases() {
        return this.rows.length > 0;
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
        if (message && (message.action === 'created' || message.action === 'updated')) {
            this.handleRefresh();
        }
    }

    handleFilterChange(event) {
        this.isLoading = true;
        this.statusFilter = event.detail.value;
    }

    handleRefresh() {
        return refreshApex(this.wiredCasesResult);
    }

    handleRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'view') {
            publish(this.messageContext, CASE_CHANNEL, { recordId: row.Id, action: 'selected' });
            this.dispatchEvent(new CustomEvent('caseselect', { detail: { caseId: row.Id } }));
        }
    }
}

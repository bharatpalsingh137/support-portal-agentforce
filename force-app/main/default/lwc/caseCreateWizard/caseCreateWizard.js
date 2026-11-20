import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import CASE_CHANNEL from '@salesforce/messageChannel/CaseSelected__c';
import getCategories from '@salesforce/apex/PortalCaseController.getCategories';
import searchFaqs from '@salesforce/apex/PortalCaseController.searchFaqs';
import createCase from '@salesforce/apex/PortalCaseController.createCase';
import { errorMessage } from 'c/errorUtils';

const SEARCH_DELAY_MS = 350;
const MIN_SEARCH_LENGTH = 3;
const LAST_STEP = 3;

/**
 * Three-step "Get help" wizard: category → details → review.
 * While the customer types a subject it suggests matching FAQs (case deflection).
 */
export default class CaseCreateWizard extends LightningElement {
    currentStep = '1';
    category;
    subject = '';
    description = '';
    categoryOptions = [];
    suggestions = [];
    isLoading = false;

    searchTimeout;

    @wire(MessageContext)
    messageContext;

    @wire(getCategories)
    wiredCategories({ data, error }) {
        if (data) {
            this.categoryOptions = data;
        } else if (error) {
            this.showToast('Could not load categories', errorMessage(error), 'error');
        }
    }

    get isStepOne() {
        return this.currentStep === '1';
    }

    get isStepTwo() {
        return this.currentStep === '2';
    }

    get isStepThree() {
        return this.currentStep === '3';
    }

    get hasSuggestions() {
        return this.suggestions.length > 0;
    }

    get categoryLabel() {
        const option = this.categoryOptions.find((o) => o.value === this.category);
        return option ? option.label : '';
    }

    handleCategoryChange(event) {
        this.category = event.detail.value;
    }

    handleSubjectChange(event) {
        this.subject = event.detail.value;
        this.scheduleFaqSearch();
    }

    handleDescriptionChange(event) {
        this.description = event.detail.value;
    }

    // Debounce so we search once the customer pauses typing, not on every key press.
    scheduleFaqSearch() {
        clearTimeout(this.searchTimeout);
        const term = this.subject;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimeout = setTimeout(() => this.runFaqSearch(term), SEARCH_DELAY_MS);
    }

    async runFaqSearch(term) {
        if (!term || term.trim().length < MIN_SEARCH_LENGTH) {
            this.suggestions = [];
            return;
        }
        try {
            this.suggestions = await searchFaqs({ term, category: this.category });
        } catch (error) {
            // Suggestions are a nice-to-have; never block case creation because of them.
            this.suggestions = [];
        }
    }

    validateCurrentStep() {
        const fields = [...this.template.querySelectorAll('lightning-radio-group, lightning-input, lightning-textarea')];
        return fields.reduce((allValid, field) => field.reportValidity() && allValid, true);
    }

    handleNext() {
        if (!this.validateCurrentStep()) {
            return;
        }
        this.currentStep = String(Math.min(Number(this.currentStep) + 1, LAST_STEP));
    }

    handleBack() {
        this.currentStep = String(Math.max(Number(this.currentStep) - 1, 1));
    }

    async handleSubmit() {
        this.isLoading = true;
        try {
            const created = await createCase({
                subject: this.subject,
                description: this.description,
                category: this.category
            });

            this.showToast(
                'Case submitted',
                `Your case ${created.CaseNumber} has been created. We'll get back to you soon.`,
                'success'
            );
            publish(this.messageContext, CASE_CHANNEL, { recordId: created.Id, action: 'created' });
            this.dispatchEvent(new CustomEvent('casecreated', { detail: { caseId: created.Id } }));
            this.reset();
        } catch (error) {
            this.showToast('Could not create your case', errorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    reset() {
        this.currentStep = '1';
        this.category = undefined;
        this.subject = '';
        this.description = '';
        this.suggestions = [];
    }

    disconnectedCallback() {
        clearTimeout(this.searchTimeout);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitFeedback from '@salesforce/apex/PortalCaseController.submitFeedback';
import { errorMessage } from 'c/errorUtils';

const LABELS = ['', 'Very unhappy', 'Unhappy', 'Okay', 'Happy', 'Very happy'];
const MAX_STARS = 5;

/**
 * Star rating + comment form shown on closed cases.
 * Fires "feedbacksubmitted" so the parent (caseDetailTimeline) can refresh.
 */
export default class CaseFeedback extends LightningElement {
    @api caseId;

    rating = 0;
    comments = '';
    errorText;
    isSubmitting = false;

    get stars() {
        const result = [];
        for (let value = 1; value <= MAX_STARS; value++) {
            const filled = value <= this.rating;
            result.push({
                value,
                symbol: filled ? '★' : '☆',
                label: `${value} star${value > 1 ? 's' : ''} - ${LABELS[value]}`,
                checked: String(value === this.rating),
                cssClass: filled ? 'star star_filled' : 'star'
            });
        }
        return result;
    }

    get ratingLabel() {
        return LABELS[this.rating] || 'Select a rating';
    }

    handleStarClick(event) {
        this.rating = Number(event.currentTarget.dataset.value);
        this.errorText = undefined;
    }

    handleCommentsChange(event) {
        this.comments = event.detail.value;
    }

    async handleSubmit() {
        if (this.rating < 1) {
            this.errorText = 'Please choose a star rating.';
            return;
        }
        this.isSubmitting = true;
        this.errorText = undefined;
        try {
            await submitFeedback({ caseId: this.caseId, rating: this.rating, comments: this.comments });
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Thank you!', message: 'Your feedback was submitted.', variant: 'success' })
            );
            this.dispatchEvent(new CustomEvent('feedbacksubmitted', { detail: { rating: this.rating } }));
        } catch (error) {
            this.errorText = errorMessage(error);
        } finally {
            this.isSubmitting = false;
        }
    }
}

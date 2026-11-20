import { createElement } from 'lwc';
import CaseFeedback from 'c/caseFeedback';
import submitFeedback from '@salesforce/apex/PortalCaseController.submitFeedback';

jest.mock(
    '@salesforce/apex/PortalCaseController.submitFeedback',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const CASE_ID = '500000000000001AAA';

function flushPromises() {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function render() {
    const element = createElement('c-case-feedback', { is: CaseFeedback });
    element.caseId = CASE_ID;
    document.body.appendChild(element);
    return element;
}

describe('c-case-feedback', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders five unselected stars', () => {
        const element = render();
        const stars = element.shadowRoot.querySelectorAll('button.star');
        expect(stars.length).toBe(5);
        expect(element.shadowRoot.querySelector('[data-id="rating-label"]').textContent).toBe('Select a rating');
    });

    it('fills stars up to the clicked one', async () => {
        const element = render();
        element.shadowRoot.querySelectorAll('button.star')[3].click();
        await Promise.resolve();

        expect(element.shadowRoot.querySelectorAll('button.star_filled').length).toBe(4);
        expect(element.shadowRoot.querySelector('[data-id="rating-label"]').textContent).toBe('Happy');
    });

    it('shows an error when submitting without a rating', async () => {
        const element = render();
        element.shadowRoot.querySelector('lightning-button').click();
        await Promise.resolve();

        expect(submitFeedback).not.toHaveBeenCalled();
        expect(element.shadowRoot.querySelector('[data-id="error"]').textContent).toBe('Please choose a star rating.');
    });

    it('calls Apex and fires feedbacksubmitted on success', async () => {
        submitFeedback.mockResolvedValue('a00000000000001AAA');
        const element = render();
        const handler = jest.fn();
        element.addEventListener('feedbacksubmitted', handler);

        element.shadowRoot.querySelectorAll('button.star')[4].click();
        await Promise.resolve();
        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();

        expect(submitFeedback).toHaveBeenCalledWith({ caseId: CASE_ID, rating: 5, comments: '' });
        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail.rating).toBe(5);
    });

    it('shows the Apex error message on failure', async () => {
        submitFeedback.mockRejectedValue({ body: { message: 'You have already left feedback for this case.' } });
        const element = render();

        element.shadowRoot.querySelectorAll('button.star')[0].click();
        await Promise.resolve();
        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="error"]').textContent).toBe(
            'You have already left feedback for this case.'
        );
    });
});

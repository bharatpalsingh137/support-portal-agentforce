import { createElement } from 'lwc';
import MyCases from 'c/myCases';
import getMyCases from '@salesforce/apex/PortalCaseController.getMyCases';
import { publish } from 'lightning/messageService';

jest.mock(
    '@salesforce/apex/PortalCaseController.getMyCases',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const MOCK_CASES = [
    {
        Id: '500000000000001AAA',
        CaseNumber: '00001001',
        Subject: 'Charged twice',
        Status: 'Waiting on Customer',
        Priority: 'High',
        Product_Category__c: 'Billing',
        LastModifiedDate: '2026-11-18T10:00:00.000Z'
    },
    {
        Id: '500000000000002AAA',
        CaseNumber: '00001002',
        Subject: 'App crashes',
        Status: 'Working',
        Priority: 'High',
        Product_Category__c: 'Technical',
        LastModifiedDate: '2026-11-17T10:00:00.000Z'
    }
];

function render() {
    const element = createElement('c-my-cases', { is: MyCases });
    document.body.appendChild(element);
    return element;
}

describe('c-my-cases', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders cases in the datatable with friendly status labels', async () => {
        const element = render();
        getMyCases.emit(MOCK_CASES);
        await Promise.resolve();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table).not.toBeNull();
        expect(table.data.length).toBe(2);
        expect(table.data[0].statusLabel).toBe('Waiting on you');
        expect(table.data[1].statusLabel).toBe('Working');
    });

    it('shows the empty state when there are no cases', async () => {
        const element = render();
        getMyCases.emit([]);
        await Promise.resolve();

        expect(element.shadowRoot.querySelector('[data-id="empty"]')).not.toBeNull();
    });

    it('shows the error message when Apex fails', async () => {
        const element = render();
        getMyCases.error({ message: 'Insufficient access' });
        await Promise.resolve();

        expect(element.shadowRoot.querySelector('[data-id="error"]')).not.toBeNull();
    });

    it('publishes the selected case on row action', async () => {
        const element = render();
        getMyCases.emit(MOCK_CASES);
        await Promise.resolve();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        table.dispatchEvent(
            new CustomEvent('rowaction', { detail: { action: { name: 'view' }, row: MOCK_CASES[1] } })
        );

        expect(publish).toHaveBeenCalledWith(undefined, expect.anything(), {
            recordId: MOCK_CASES[1].Id,
            action: 'selected'
        });
    });
});

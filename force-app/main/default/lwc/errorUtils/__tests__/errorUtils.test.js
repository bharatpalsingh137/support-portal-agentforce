import { reduceErrors, errorMessage } from 'c/errorUtils';

describe('c/errorUtils', () => {
    it('handles Apex AuraHandledException errors', () => {
        expect(reduceErrors({ body: { message: 'Apex says no' } })).toEqual(['Apex says no']);
    });

    it('handles UI API array errors', () => {
        expect(reduceErrors({ body: [{ message: 'one' }, { message: 'two' }] })).toEqual(['one', 'two']);
    });

    it('handles page errors', () => {
        expect(reduceErrors({ body: { pageErrors: [{ message: 'Validation failed' }] } })).toEqual([
            'Validation failed'
        ]);
    });

    it('handles JS errors and lists of errors', () => {
        expect(reduceErrors([new Error('boom'), null, { statusText: 'Bad Request' }])).toEqual([
            'boom',
            'Bad Request'
        ]);
    });

    it('joins messages for toasts', () => {
        expect(errorMessage([{ body: { message: 'a' } }, { body: { message: 'b' } }])).toBe('a, b');
    });
});

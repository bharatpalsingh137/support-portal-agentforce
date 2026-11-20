/**
 * Turns the many error shapes returned by Apex, LDS and JS into a flat list of messages.
 * @param {Object|Object[]} errors
 * @returns {string[]}
 */
export function reduceErrors(errors) {
    const list = Array.isArray(errors) ? errors : [errors];

    return list
        .filter((error) => !!error)
        .map((error) => {
            // UI API read errors
            if (Array.isArray(error.body)) {
                return error.body.map((e) => e.message);
            }
            // Page level DML errors
            if (error.body && Array.isArray(error.body.pageErrors) && error.body.pageErrors.length > 0) {
                return error.body.pageErrors.map((e) => e.message);
            }
            // Apex AuraHandledException and UI API DML errors
            if (error.body && typeof error.body.message === 'string') {
                return error.body.message;
            }
            // JS errors
            if (typeof error.message === 'string') {
                return error.message;
            }
            return error.statusText || 'Unknown error';
        })
        .reduce((all, current) => all.concat(current), [])
        .filter((message) => !!message);
}

/** Single string version for toasts. */
export function errorMessage(errors) {
    return reduceErrors(errors).join(', ');
}

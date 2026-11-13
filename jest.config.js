const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

const MOCKS = '<rootDir>/force-app/main/default/lwc/customerSummaryPanel/__tests__/mocks';

module.exports = {
    ...jestConfig,
    roots: ['<rootDir>/force-app'],
    testMatch: ['**/__tests__/**/*.test.js'],
    // lightning/platformUtilityBarApi and lightning/accApi have no sfdx-lwc-jest stub.
    moduleNameMapper: {
        '^lightning/platformUtilityBarApi$': MOCKS + '/platformUtilityBarApi.js',
        '^lightning/accApi$': MOCKS + '/accApi.js'
    },
    setupFilesAfterEnv: [...(jestConfig.setupFilesAfterEnv || []), MOCKS + '/setup.js'],
    testPathIgnorePatterns: ['<rootDir>/node_modules/', '<rootDir>/.sfdx/', '<rootDir>/.sf/']
};

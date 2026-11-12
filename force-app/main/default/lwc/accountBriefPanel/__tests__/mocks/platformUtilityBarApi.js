// Jest stub for lightning/platformUtilityBarApi (sfdx-lwc-jest ships none).
import { createTestWireAdapter } from '@salesforce/wire-service-jest-util';

export const EnclosingUtilityId = createTestWireAdapter(jest.fn());
export const open = jest.fn(() => Promise.resolve(true));
export const minimize = jest.fn(() => Promise.resolve(true));

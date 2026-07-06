import * as admin from 'firebase-admin';

admin.initializeApp();

// Export Cloud Functions
export * from './onSubmissionCreated';
export * from './deduplicateAndCluster';
export * from './scoreAndRank';
export * from './voiceIntake';


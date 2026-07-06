import * as admin from 'firebase-admin';

// NOTE: To run this, you need a service account key from your Firebase Project
// Export it as GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

admin.initializeApp();
const db = admin.firestore();

async function seedData() {
  console.log('Seeding JanPriority dummy data...');
  
  // 1. Create a dummy cluster
  const clusterRef = db.collection('clusters').doc('dummy_cluster_1');
  await clusterRef.set({
    title: 'School Upgrade in Ward 4',
    category: 'Education',
    ward: 'Ward 4',
    submissionCount: 340,
    representativeSubmissionIds: ['dummy_sub_1', 'dummy_sub_2'],
    centroid: { lat: 20.5937, lng: 78.9629 },
    status: 'Under Review',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Create dummy submissions
  await db.collection('submissions').doc('dummy_sub_1').set({
    citizenPhone: 'hashed_phone_1',
    mode: 'text',
    originalText: 'The primary school roof is leaking.',
    originalLanguage: 'en',
    translatedText: 'The primary school roof is leaking.',
    category: 'Education',
    extractedLocation: { ward: 'Ward 4' },
    severity: 0.7,
    sentiment: -0.4,
    status: 'Under Review',
    clusterId: 'dummy_cluster_1',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 3. Create a dummy ranking
  await db.collection('rankings').doc('dummy_cluster_1').set({
    clusterId: 'dummy_cluster_1',
    score: 94.2,
    rank: 1,
    explanation: 'Ranked #1 because 340 citizens raised this, the school is 42% over its rated capacity, and no funds are currently allocated to address it.',
    weightsUsed: { w1: 0.3, w2: 0.25, w3: 0.2, w4: 0.15, w5: 0.1 },
    computedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('Seed complete. Check Firestore.');
}

if (require.main === module) {
  seedData().catch(console.error);
}

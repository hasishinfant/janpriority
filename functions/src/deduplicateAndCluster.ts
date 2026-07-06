import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'MOCK_KEY');

function getDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Radius of the earth in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function cosineSimilarity(vecA: number[], vecB: number[]): number {
  if (vecA.length !== vecB.length) return 0;
  let dotProduct = 0.0;
  let normA = 0.0;
  let normB = 0.0;
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

export const deduplicateAndCluster = functions.firestore
  .document('submissions/{submissionId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const prevData = change.before.data();

    // Run when status changes from Submitted to Under Review
    if (prevData.status === 'Submitted' && newData.status === 'Under Review') {
      const db = admin.firestore();
      const submissionId = context.params.submissionId;

      const subText = newData.translatedText || newData.originalText || '';
      const category = newData.category || 'Other';
      const subLoc = newData.location as admin.firestore.GeoPoint;
      const ward = newData.extractedLocation?.ward || 'General';

      if (!subLoc) {
        console.warn('Submission has no location coordinate, skipping clustering');
        return;
      }

      // 1. Generate Embedding
      let embedding: number[] = [];
      try {
        const model = genAI.getGenerativeModel({ model: 'text-embedding-004' });
        const result = await model.embedContent(subText);
        embedding = result.embedding.values;
      } catch (embErr) {
        console.error('Failed to generate embedding with Gemini:', embErr);
        // Fallback random embedding mock for local test/demo if no API key
        embedding = Array.from({ length: 768 }, () => Math.random() - 0.5);
      }

      // 2. Query active clusters of the same category
      const clustersRef = db.collection('clusters');
      const querySnapshot = await clustersRef
        .where('category', '==', category)
        .where('status', '==', 'Under Review')
        .get();

      let matchedClusterId: string | null = null;
      let highestSimilarity = 0;

      for (const doc of querySnapshot.docs) {
        const clusterData = doc.data();
        const clusterCentroid = clusterData.centroid as admin.firestore.GeoPoint;
        if (!clusterCentroid) continue;

        // Check if within 1km geofence
        const dist = getDistanceKm(subLoc.latitude, subLoc.longitude, clusterCentroid.latitude, clusterCentroid.longitude);
        if (dist <= 1.0) {
          const clusterEmbedding = clusterData.embedding as number[];
          if (clusterEmbedding && embedding.length > 0) {
            const similarity = cosineSimilarity(embedding, clusterEmbedding);
            if (similarity > highestSimilarity) {
              highestSimilarity = similarity;
              matchedClusterId = doc.id;
            }
          }
        }
      }

      const similarityThreshold = 0.82;

      if (matchedClusterId && highestSimilarity >= similarityThreshold) {
        // Merge into existing cluster
        const clusterDocRef = db.collection('clusters').doc(matchedClusterId);
        
        await db.runTransaction(async (transaction) => {
          const clusterDoc = await transaction.get(clusterDocRef);
          const currentData = clusterDoc.data();
          if (!currentData) return;

          const newCount = (currentData.submissionCount || 0) + 1;
          const currentCentroid = currentData.centroid as admin.firestore.GeoPoint;

          // Compute new running average centroid
          const newLat = (currentCentroid.latitude * (newCount - 1) + subLoc.latitude) / newCount;
          const newLng = (currentCentroid.longitude * (newCount - 1) + subLoc.longitude) / newCount;

          transaction.update(clusterDocRef, {
            submissionCount: newCount,
            representativeSubmissionIds: admin.firestore.FieldValue.arrayUnion(submissionId),
            centroid: new admin.firestore.GeoPoint(newLat, newLng),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        await change.after.ref.update({
          clusterId: matchedClusterId,
          status: 'Processed'
        });
        console.log(`Merged submission ${submissionId} into cluster ${matchedClusterId} (similarity: ${highestSimilarity.toFixed(3)})`);
      } else {
        // Create a new cluster
        // Shorten description for title using Gemini or substring
        let clusterTitle = `Issue in ${ward}`;
        if (subText) {
          try {
            const tModel = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
            const titlePrompt = `Generate a short 4-6 word title summarizing this civic grievance: "${subText}". Do not wrap in quotes or add preamble.`;
            const tResult = await tModel.generateContent(titlePrompt);
            clusterTitle = (await tResult.response).text().trim().replace(/^"(.*)"$/, '$1');
          } catch (tErr) {
            console.error('Failed to generate cluster title, using fallback substring:', tErr);
            clusterTitle = subText.length > 30 ? subText.substring(0, 30) + '...' : subText;
          }
        }

        const newCluster = {
          title: clusterTitle,
          category: category,
          ward: ward,
          submissionCount: 1,
          representativeSubmissionIds: [submissionId],
          centroid: subLoc,
          embedding: embedding,
          status: 'Under Review',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const newClusterRef = await clustersRef.add(newCluster);
        await change.after.ref.update({
          clusterId: newClusterRef.id,
          status: 'Processed'
        });
        console.log(`Created new cluster ${newClusterRef.id} for submission ${submissionId}`);
      }
    }
  });

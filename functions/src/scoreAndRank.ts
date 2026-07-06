import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';
import * as fs from 'fs';
import * as path from 'path';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'MOCK_KEY');

interface CensusRow {
  wardOrVillage: string;
  totalPopulation: number;
  scPopulation: number;
  stPopulation: number;
  scStPercentage: number;
}

interface UdiseRow {
  wardOrVillage: string;
  schoolDistanceKm: number;
  enrollmentRatio: number;
}

function parseCensusCsv(): CensusRow[] {
  // Use path pointing to functions/src/data in workspace
  const filePath = path.join(__dirname, '..', 'src', 'data', 'census_sc_st.csv');
  if (!fs.existsSync(filePath)) {
    console.warn(`Census file not found at ${filePath}, using stub data.`);
    return [];
  }
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const rows: CensusRow[] = [];
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;
    const parts = line.split(',');
    if (parts.length >= 5) {
      rows.push({
        wardOrVillage: parts[0].trim(),
        totalPopulation: parseInt(parts[1]) || 0,
        scPopulation: parseInt(parts[2]) || 0,
        stPopulation: parseInt(parts[3]) || 0,
        scStPercentage: parseFloat(parts[4]) || 0,
      });
    }
  }
  return rows;
}

function parseUdiseCsv(): UdiseRow[] {
  const filePath = path.join(__dirname, '..', 'src', 'data', 'udise_school_distance.csv');
  if (!fs.existsSync(filePath)) {
    console.warn(`UDISE file not found at ${filePath}, using stub data.`);
    return [];
  }
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const rows: UdiseRow[] = [];
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;
    const parts = line.split(',');
    if (parts.length >= 3) {
      rows.push({
        wardOrVillage: parts[0].trim(),
        schoolDistanceKm: parseFloat(parts[1]) || 0,
        enrollmentRatio: parseFloat(parts[2]) || 0,
      });
    }
  }
  return rows;
}

export const scoreAndRank = functions.https.onCall(async (data, context) => {
  const db = admin.firestore();
  const clustersSnapshot = await db.collection('clusters').where('status', '==', 'Under Review').get();

  const weights = data.weights || {
    w1: 0.3,   // Citizen demand
    w2: 0.25,  // Severity
    w3: 0.2,   // Benchmark gap
    w4: 0.15,  // Demand trend
    w5: 0.1    // Budget feasibility
  };

  // Load datasets
  const censusData = parseCensusCsv();
  const udiseData = parseUdiseCsv();

  const rankedClusters: any[] = [];
  const rankingsBatch = db.batch();

  for (const doc of clustersSnapshot.docs) {
    const cluster = doc.data();
    const clusterId = doc.id;
    const ward = cluster.ward || 'General';
    const category = cluster.category || 'Other';

    // 1. Calculate Citizen Demand (normalized)
    const nCitizenMentions = Math.min((cluster.submissionCount || 1) / 300, 1.0);

    // 2. Fetch demographic gap (Census) & infra gap (UDISE)
    const censusRow = censusData.find(r => r.wardOrVillage.toLowerCase() === ward.toLowerCase()) || 
                      censusData.find(r => r.wardOrVillage === 'General');
    const udiseRow = udiseData.find(r => r.wardOrVillage.toLowerCase() === ward.toLowerCase()) || 
                     udiseData.find(r => r.wardOrVillage === 'General');

    const scStGap = censusRow ? (censusRow.scStPercentage / 100) : 0.15;
    const schoolGap = udiseRow ? Math.min(udiseRow.schoolDistanceKm / 15.0, 1.0) : 0.2;

    // Composite Gap indicator based on category
    let gapIndicator = 0.2;
    if (category === 'Education') {
      gapIndicator = (0.7 * schoolGap) + (0.3 * scStGap);
    } else {
      gapIndicator = (0.3 * schoolGap) + (0.7 * scStGap);
    }

    // 3. Mock other metrics
    const severityScore = cluster.severity || 0.75;
    const demandTrend = 0.65; // Simulated positive growth trend
    const budgetFeas = 0.85;  // Simulated project feasibility

    // 4. Calculate Final Weighted Priority Score
    const score = (weights.w1 * nCitizenMentions) +
                  (weights.w2 * severityScore) +
                  (weights.w3 * gapIndicator) +
                  (weights.w4 * demandTrend) +
                  (weights.w5 * budgetFeas);
    const finalScore = score * 100;

    rankedClusters.push({
      clusterId,
      title: cluster.title,
      category,
      ward,
      submissionCount: cluster.submissionCount || 1,
      score: parseFloat(finalScore.toFixed(1)),
      scStGap: scStGap,
      schoolGap: schoolGap,
      weightsUsed: weights,
    });
  }

  // Sort by score descending
  rankedClusters.sort((a, b) => b.score - a.score);

  // Generate justification with Gemini and commit to rankings collection
  for (let i = 0; i < rankedClusters.length; i++) {
    const item = rankedClusters[i];
    const rank = i + 1;

    let explanation = `Ranked #${rank} — ${item.submissionCount} requests in ${item.ward}; high demographic priority.`;

    try {
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      const prompt = `
        You are an AI analyst for a Member of Parliament's office in India.
        Write a concise, exactly 1-sentence plain-language justification summarizing why the following project cluster is ranked at #${rank} out of ${rankedClusters.length}:
        
        Cluster Title: "${item.title}"
        Category: "${item.category}"
        Location: "${item.ward}"
        Citizen Submissions: ${item.submissionCount}
        Priority Score: ${item.score}/100
        SC/ST Population: ${(item.scStGap * 100).toFixed(0)}%
        School Distance: ${(item.schoolGap * 15).toFixed(1)} km
        
        Example format: "Ranked #2 — ${item.submissionCount} verified reports across ${item.ward}; area has ${(item.schoolGap * 100).toFixed(0)}% higher school-distance than district average."
        Make it sound professional, data-driven, and clear for a non-technical viewer. Do not use markdown styling.
      `;

      const result = await model.generateContent(prompt);
      explanation = (await result.response).text().trim().replace(/^"(.*)"$/, '$1');
    } catch (e) {
      console.error(`Gemini explanation generation failed for cluster ${item.clusterId}:`, e);
    }

    const rankDocRef = db.collection('rankings').doc(item.clusterId);
    rankingsBatch.set(rankDocRef, {
      clusterId: item.clusterId,
      score: item.score,
      explanation: explanation,
      weightsUsed: item.weightsUsed,
      rank: rank,
      computedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Also update cluster's ranking details for ease of read
    const clusterDocRef = db.collection('clusters').doc(item.clusterId);
    rankingsBatch.update(clusterDocRef, {
      priorityScore: item.score,
      priorityJustification: explanation,
      enrichment: {
        scStGap: item.scStGap,
        schoolGap: item.schoolGap
      }
    });
  }

  await rankingsBatch.commit();
  return { success: true, count: rankedClusters.length };
});

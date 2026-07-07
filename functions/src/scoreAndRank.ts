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

export const scoreAndRank = functions.https.onCall(async (data, context) => {
  const db = admin.firestore();
  
  // 1. Get all active clusters
  const clustersSnapshot = await db.collection('clusters').where('status', '==', 'Under Review').get();
  
  // 2. Fetch all village demographics for closest-coordinate matching
  const demographicsSnapshot = await db.collection('demographics').get();
  const villages = demographicsSnapshot.docs.map(doc => doc.data());
  
  const weights = data.weights || {
    w1: 0.3,   // Citizen demand
    w2: 0.25,  // Severity
    w3: 0.2,   // Demographic/Infra gap
    w4: 0.15,  // Demand trend
    w5: 0.1    // Budget feasibility
  };

  const rankedClusters: any[] = [];
  const rankingsBatch = db.batch();

  for (const doc of clustersSnapshot.docs) {
    const cluster = doc.data();
    const clusterId = doc.id;
    const category = cluster.category || 'Other';
    const centroid = cluster.centroid as admin.firestore.GeoPoint;
    const ward = cluster.ward || 'General';

    // A. Match closest village in demographics
    let closestVillage: any = null;
    let minDistance = 3.0; // 3km threshold for local match

    if (centroid) {
      for (const v of villages) {
        if (v.location) {
          const dist = getDistanceKm(centroid.latitude, centroid.longitude, v.location.latitude, v.location.longitude);
          if (dist < minDistance) {
            minDistance = dist;
            closestVillage = v;
          }
        }
      }
    }

    // B. Calculate Gap Indicator based on local village or state benchmarks fallback
    let gapIndicator = 0.2;
    let scPopulationRange: string | null = null;
    let stPopulationRange: string | null = null;
    let schoolStatus: string | null = null;
    let medicalStatus: string | null = null;
    let waterStatus: string | null = null;
    let electricityStatus: string | null = null;
    let isFallback = false;

    if (closestVillage) {
      // Local village match found!
      scPopulationRange = closestVillage.sc_population_pct_range;
      stPopulationRange = closestVillage.st_population_pct_range;
      schoolStatus = closestVillage.schools_in_village_pp_p_m_s;
      medicalStatus = closestVillage.medical_facility_in_village;
      waterStatus = closestVillage.drinking_water_available;
      electricityStatus = closestVillage.electricity_domestic;

      // Calculate numeric gap score
      let scGap = 0.1;
      if (scPopulationRange) {
        if (scPopulationRange.includes('21-30')) scGap = 0.25;
        else if (scPopulationRange.includes('11-20')) scGap = 0.15;
        else if (scPopulationRange.includes('5-10')) scGap = 0.08;
      }
      
      let categoryGap = 0.2;
      if (category === 'Education') {
        const hasSchool = schoolStatus && schoolStatus.toLowerCase().startsWith('yes');
        categoryGap = hasSchool ? 0.2 : 0.8;
      } else if (category === 'Health') {
        const hasMedical = medicalStatus && medicalStatus.toLowerCase().startsWith('yes');
        categoryGap = hasMedical ? 0.2 : 0.8;
      } else if (category === 'Water') {
        const hasWater = waterStatus && waterStatus.toLowerCase().startsWith('yes');
        categoryGap = hasWater ? 0.2 : 0.9;
      } else if (category === 'Electricity') {
        const hasElec = electricityStatus && electricityStatus.toLowerCase().startsWith('yes');
        categoryGap = hasElec ? 0.1 : 0.9;
      }

      gapIndicator = (0.6 * categoryGap) + (0.4 * scGap);
    } else {
      // No local village match, query state benchmarks fallback
      isFallback = true;
      const benchmarkDoc = await db.collection('state_benchmarks').doc(ward).get();
      const backupDoc = await db.collection('state_benchmarks').doc('General').get();
      const benchmark = benchmarkDoc.exists ? benchmarkDoc.data() : (backupDoc.exists ? backupDoc.data() : null);

      if (benchmark) {
        const scStPct = (benchmark.sc_st_percentage || 12) / 100;
        const schoolDistKm = benchmark.school_distance_km || 4.0;
        const schoolGap = Math.min(schoolDistKm / 15.0, 1.0);
        gapIndicator = category === 'Education' ? (0.7 * schoolGap + 0.3 * scStPct) : (0.3 * schoolGap + 0.7 * scStPct);
      }
    }

    // C. Calculate final priority score
    const nCitizenMentions = Math.min((cluster.submissionCount || 1) / 300, 1.0);
    const severityScore = cluster.severity || 0.75;
    const demandTrend = 0.65;
    const budgetFeas = 0.85;

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
      gapIndicator,
      isFallback,
      villageName: closestVillage ? closestVillage.village_name : null,
      scPopulationRange,
      stPopulationRange,
      schoolStatus,
      medicalStatus,
      waterStatus,
      electricityStatus,
      weightsUsed: weights
    });
  }

  // Sort by score descending
  rankedClusters.sort((a, b) => b.score - a.score);

  // 3. Generate justification with Gemini and save
  for (let i = 0; i < rankedClusters.length; i++) {
    const item = rankedClusters[i];
    const rank = i + 1;

    // Generate demographic statistics snippet for Gemini prompt
    let statsSnippet = '';
    if (item.isFallback) {
      statsSnippet = `District/State Benchmark Data Used: area is estimated to have regional averages.`;
    } else {
      statsSnippet = `hyperlocal Census 2011 demographics for village ${item.villageName}:
        - SC Population Range: ${item.scPopulationRange || 'Data not available'}
        - School Facility: ${item.schoolStatus || 'Data not available'}
        - Medical Facility: ${item.medicalStatus || 'Data not available'}
        - Drinking Water: ${item.waterStatus || 'Data not available'}`;
    }

    let explanation = `Ranked #${rank} — ${item.submissionCount} requests in ${item.ward}; prioritised based on demographic infrastructure needs.`;

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
        ${statsSnippet}
        
        Requirements:
        1. Keep it strictly to one sentence.
        2. Incorporate real numbers or facts from the demographics listed above if available (e.g., if there is no school, or if SC population is in a specific range like '21-30%').
        3. If regional averages are used (District/State Benchmark), you MUST explicitly prefix or suffix the statement with "(state/district benchmark)".
        4. Do not mention "Gemini", "AI model", or use markdown styling.
        
        Example format: "Ranked #2 — ${item.submissionCount} verified reports across ${item.ward}; this area has ${item.scPopulationRange || '11-20'}% SC population and no medical facility in-village."
      `;

      const result = await model.generateContent(prompt);
      explanation = (await result.response).text().trim().replace(/^"(.*)"$/, '$1');
    } catch (e) {
      console.error(`Gemini explanation generation failed for cluster ${item.clusterId}:`, e);
    }

    // Save rankings
    const rankDocRef = db.collection('rankings').doc(item.clusterId);
    rankingsBatch.set(rankDocRef, {
      clusterId: item.clusterId,
      score: item.score,
      explanation: explanation,
      weightsUsed: item.weightsUsed,
      rank: rank,
      computedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update cluster ranking details
    const clusterDocRef = db.collection('clusters').doc(item.clusterId);
    
    const enrichmentData: any = {
      isFallbackBenchmark: item.isFallback,
      benchmarkLabel: item.isFallback ? 'state/district benchmark' : 'hyperlocal census data',
      matchedVillage: item.villageName,
      scPopulationRange: item.scPopulationRange || 'data not available',
      stPopulationRange: item.stPopulationRange || 'data not available',
      schoolStatus: item.schoolStatus || 'data not available',
      medicalStatus: item.medicalStatus || 'data not available',
      waterStatus: item.waterStatus || 'data not available'
    };

    rankingsBatch.update(clusterDocRef, {
      priorityScore: item.score,
      priorityJustification: explanation,
      enrichment: enrichmentData,
      status: 'Prioritized',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }

  await rankingsBatch.commit();
  return { success: true, count: rankedClusters.length };
});

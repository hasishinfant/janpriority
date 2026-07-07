import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// Coordinates mapping for Bangalore South villages (fallback to guarantee demo map works)
const VILLAGE_COORDINATES: Record<string, { lat: number; lng: number }> = {
  'seshagiripura': { lat: 12.9080, lng: 77.4720 },
  'chikkellur': { lat: 12.9220, lng: 77.4350 },
  'chikkellur venkatapura': { lat: 12.9230, lng: 77.4370 },
  'chikkellur ramapura': { lat: 12.9210, lng: 77.4390 },
  'm.krishnasagara': { lat: 12.8856, lng: 77.4423 },
  'kenchanapura': { lat: 12.9192, lng: 77.4589 },
  'kommaghatta': { lat: 12.9145, lng: 77.4789 },
  'sulikere': { lat: 12.9126, lng: 77.4628 },
  'maragondanahalli': { lat: 12.8640, lng: 77.4680 },
  'maligondanahalli': { lat: 12.8710, lng: 77.4750 },
  'ramohalli': { lat: 12.8988, lng: 77.4520 },
  'bheemanakuppe': { lat: 12.9056, lng: 77.4423 },
  'galihalli': { lat: 12.7234, lng: 77.2912 },
  'sulikere dananayakanahalli': { lat: 12.9126, lng: 77.4628 },
  'bwssb commercial area': { lat: 12.9806, lng: 77.6068 }
};

// Geocode utility using Google Maps Geocoding API with Gemini API key
async function geocode(address: string): Promise<{ lat: number; lng: number } | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey === 'MOCK_KEY') {
    return null;
  }

  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${apiKey}`;
  
  return new Promise((resolve) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.status === 'OK' && parsed.results && parsed.results.length > 0) {
            const loc = parsed.results[0].geometry.location;
            resolve({ lat: loc.lat, lng: loc.lng });
          } else {
            resolve(null);
          }
        } catch {
          resolve(null);
        }
      });
    }).on('error', () => {
      resolve(null);
    });
  });
}

function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;
  
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

// Clean Firestore collection utility
async function deleteCollection(collectionPath: string) {
  const collectionRef = db.collection(collectionPath);
  const snapshot = await collectionRef.get();
  const batch = db.batch();
  snapshot.docs.forEach((doc: any) => {
    batch.delete(doc.ref);
  });
  await batch.commit();
}

async function seedData() {
  console.log('--- Start Seeding JanPriority Database ---');
  
  const dataDir = path.join(__dirname, '..', 'functions', 'src', 'data');
  
  // 1. Seed MPLADS Works
  console.log('Seeding mplads_works...');
  await deleteCollection('mplads_works');
  
  const worksPath = path.join(dataDir, 'mplads_works.json');
  if (!fs.existsSync(worksPath)) {
    throw new Error(`File not found: ${worksPath}`);
  }
  const worksData = JSON.parse(fs.readFileSync(worksPath, 'utf8'));
  
  // Save global stats to mp_metadata
  await db.collection('mp_metadata').doc('sitting_mp').set({
    mp_info: worksData.mp_info,
    fund_summary: worksData.fund_summary,
    yearly_trends: worksData.yearly_trends,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  for (const work of worksData.works) {
    const villageName = work.matched_census_village || work.area_name || '';
    let coords = VILLAGE_COORDINATES[villageName.toLowerCase()];
    
    if (villageName) {
      const geoResult = await geocode(`${villageName}, Karnataka, India`);
      if (geoResult) {
        coords = geoResult;
      }
    }
    
    const lat = coords?.lat || null;
    const lng = coords?.lng || null;
    const locationGeoPoint = lat && lng ? new admin.firestore.GeoPoint(lat, lng) : null;
    
    // Normalize status to completed/recommended/in_progress
    let workStatus = 'recommended';
    if (work.status === 'completed') {
      workStatus = 'completed';
    } else if (work.status === 'in_progress' || work.status === 'recommended') {
      workStatus = work.status;
    }
    
    await db.collection('mplads_works').doc(work.id).set({
      id: work.id,
      category: work.category || 'Other',
      work_description: work.description,
      village_area: work.area_name || 'Not Available',
      matched_census_village: work.matched_census_village || null,
      matched_census_location_code: work.matched_census_location_code || null,
      amount: work.amount_lakh || 0,
      status: workStatus,
      date: work.date,
      sc_st_tagged: !!work.sc_st_tagged,
      lat: lat,
      lng: lng,
      location: locationGeoPoint
    });
  }
  console.log(`Successfully seeded ${worksData.works.length} works.`);
  
  // 2. Seed Demographics
  console.log('Seeding demographics...');
  await deleteCollection('demographics');
  
  const demographicsPath = path.join(dataDir, 'demographics_bangalore_south.csv');
  if (!fs.existsSync(demographicsPath)) {
    throw new Error(`File not found: ${demographicsPath}`);
  }
  
  const demoLines = fs.readFileSync(demographicsPath, 'utf8').split('\n');
  const demoHeaders = parseCSVLine(demoLines[0]);
  
  let demoCount = 0;
  for (let i = 1; i < demoLines.length; i++) {
    const line = demoLines[i].trim();
    if (!line) continue;
    
    const parts = parseCSVLine(line);
    if (parts.length < demoHeaders.length) continue;
    
    const villageName = parts[0];
    const locationCode = parts[1];
    
    let coords = VILLAGE_COORDINATES[villageName.toLowerCase()];
    const geoResult = await geocode(`${villageName}, Karnataka, India`);
    if (geoResult) {
      coords = geoResult;
    }
    
    const lat = coords?.lat || null;
    const lng = coords?.lng || null;
    const locationGeoPoint = lat && lng ? new admin.firestore.GeoPoint(lat, lng) : null;
    
    // Clean fields mapping (replace 'not_found_in_extracted_range' with null)
    const cleanVal = (val: string) => val === 'not_found_in_extracted_range' ? null : val;
    
    await db.collection('demographics').doc(locationCode).set({
      village_name: villageName,
      location_code: locationCode,
      area_ha: parseFloat(parts[2]) || null,
      population_2011: parseInt(parts[3]) || null,
      households: parseInt(parts[4]) || null,
      sc_population_pct_range: cleanVal(parts[5]),
      st_population_pct_range: cleanVal(parts[6]),
      schools_in_village_pp_p_m_s: cleanVal(parts[7]),
      higher_ed_available_in_village: cleanVal(parts[8]),
      medical_facility_in_village: cleanVal(parts[9]),
      drinking_water_available: cleanVal(parts[10]),
      electricity_domestic: cleanVal(parts[11]),
      nearest_town: parts[12] || null,
      nearest_town_distance_km_range: parts[13] || null,
      lat: lat,
      lng: lng,
      location: locationGeoPoint
    });
    demoCount++;
  }
  console.log(`Successfully seeded ${demoCount} village demographics.`);
  
  // 3. Seed Environmental Monitoring (Noise Levels)
  console.log('Seeding env_monitoring...');
  await deleteCollection('env_monitoring');
  
  const envPath = path.join(dataDir, 'noise_levels_bwssb.csv');
  if (!fs.existsSync(envPath)) {
    throw new Error(`File not found: ${envPath}`);
  }
  
  const envLines = fs.readFileSync(envPath, 'utf8').split('\n');
  let envCount = 0;
  
  const stationLoc = VILLAGE_COORDINATES['bwssb commercial area'];
  const stationGeoPoint = new admin.firestore.GeoPoint(stationLoc.lat, stationLoc.lng);
  
  for (let i = 2; i < envLines.length; i++) {
    const line = envLines[i].trim();
    if (!line) continue;
    if (line.startsWith('Note:')) break; // End of actual data
    
    const parts = parseCSVLine(line);
    if (parts.length < 11) continue;
    
    const dateStr = parts[0];
    if (!dateStr || dateStr.includes(',')) continue;
    
    await db.collection('env_monitoring').add({
      station_name: 'BWSSB Commercial Area',
      date: dateStr,
      limit_day: parseFloat(parts[1]) || 65,
      leq_day: parseFloat(parts[2]) || null,
      lmin_day: parseFloat(parts[3]) || null,
      lmax_day: parseFloat(parts[4]) || null,
      increase_day: parts[5] || 'Within limit',
      limit_night: parseFloat(parts[6]) || 55,
      leq_night: parseFloat(parts[7]) || null,
      lmin_night: parseFloat(parts[8]) || null,
      lmax_night: parseFloat(parts[9]) || null,
      increase_night: parts[10] || 'Within limit',
      num_days: parts[11] || '30 Days',
      lat: stationLoc.lat,
      lng: stationLoc.lng,
      location: stationGeoPoint
    });
    envCount++;
  }
  console.log(`Successfully seeded ${envCount} noise level entries.`);
  
  // 4. Seed State Benchmarks
  console.log('Seeding state_benchmarks...');
  await deleteCollection('state_benchmarks');
  
  // Load census SC/ST aggregates
  const censusAggPath = path.join(dataDir, 'census_sc_st.csv');
  if (fs.existsSync(censusAggPath)) {
    const lines = fs.readFileSync(censusAggPath, 'utf8').split('\n');
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      const parts = parseCSVLine(line);
      if (parts.length >= 5) {
        const key = parts[0];
        await db.collection('state_benchmarks').doc(key).set({
          ward_or_village: key,
          total_population: parseInt(parts[1]) || 0,
          sc_population: parseInt(parts[2]) || 0,
          st_population: parseInt(parts[3]) || 0,
          sc_st_percentage: parseFloat(parts[4]) || 0,
          type: 'census_demographics'
        }, { merge: true });
      }
    }
  }
  
  // Load school distance aggregates
  const udiseAggPath = path.join(dataDir, 'udise_school_distance.csv');
  if (fs.existsSync(udiseAggPath)) {
    const lines = fs.readFileSync(udiseAggPath, 'utf8').split('\n');
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      const parts = parseCSVLine(line);
      if (parts.length >= 3) {
        const key = parts[0];
        await db.collection('state_benchmarks').doc(key).set({
          ward_or_village: key,
          school_distance_km: parseFloat(parts[1]) || 0,
          enrollment_ratio: parseFloat(parts[2]) || 0,
          type: 'udise_infrastructure'
        }, { merge: true });
      }
    }
  }
  console.log('Successfully seeded state benchmarks.');
  console.log('--- Seeding Completed Successfully ---');
}

if (require.main === module) {
  seedData().catch(console.error);
}

export { seedData };

// seed.js
// Run: node seed.js
// Requires: npm install firebase-admin csv-parse
//
// Expects target dataset files and serviceAccountKey.json in the same folder.

const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const fs = require("fs");
const { parse } = require("csv-parse/sync");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.cert(serviceAccount),
});

const db = getFirestore();

// Helper to seed a single MP Profile and its associated works
async function seedMpProfileAndWorks(jsonPath, docId) {
  if (!fs.existsSync(jsonPath)) {
    console.warn(`File not found: ${jsonPath}, skipping...`);
    return;
  }
  const raw = fs.readFileSync(jsonPath, "utf8");
  const data = JSON.parse(raw);

  // Write sitting MP profile
  await db.collection("mp_profile").doc(docId).set({
    mp_info: data.mp_info,
    fund_summary: data.fund_summary,
    yearly_trends: data.yearly_trends,
    source: data.source,
    generated_at: data.generated_at,
  });
  console.log(`Seeded mp_profile/${docId}`);

  // Write works in a batch
  const batch = db.batch();
  data.works.forEach((work) => {
    // If the work ID doesn't have the prefix yet, prefix it if it's the Bangalore MP
    // (the others are already naturally prefixed, e.g. KZ-C01, MU-C01, CH-C01)
    let workId = work.id;
    if (docId === "narayana_koragappa" && !workId.startsWith("BLR_")) {
      workId = "BLR_" + workId;
    }
    
    const ref = db.collection("mplads_works").doc(workId);
    batch.set(ref, {
      ...work,
      id: workId,
      mp_doc_id: docId,
      constituency: data.mp_info.constituency || "Bangalore South"
    });
  });
  await batch.commit();
  console.log(`Seeded ${data.works.length} documents into mplads_works for ${docId}`);
}

// Helper to seed village demographics
async function seedVillageDemographics(csvPath, constituency) {
  if (!fs.existsSync(csvPath)) {
    console.warn(`File not found: ${csvPath}, skipping...`);
    return;
  }
  const raw = fs.readFileSync(csvPath, "utf8");
  const records = parse(raw, {
    columns: true,
    skip_empty_lines: true,
  });

  const batch = db.batch();
  records.forEach((row) => {
    const ref = db.collection("demographics").doc(row.location_code);
    batch.set(ref, {
      ...row,
      constituency: constituency,
      type: "village",
      population_2011: row.population_2011 ? parseInt(row.population_2011, 10) : 0,
      households: row.households ? parseInt(row.households, 10) : 0,
    });
  });
  await batch.commit();
  console.log(`Seeded ${records.length} villages into demographics for ${constituency}`);
}

// Helper to seed slum localities
async function seedSlumLocalities(csvPath, constituency) {
  if (!fs.existsSync(csvPath)) {
    console.warn(`File not found: ${csvPath}, skipping...`);
    return;
  }
  const raw = fs.readFileSync(csvPath, "utf8");
  const records = parse(raw, {
    columns: true,
    skip_empty_lines: true,
  });

  const batch = db.batch();
  records.forEach((row) => {
    // Generate a unique ID using slum name and constituency
    const cleanSlumName = row.slum_name.trim();
    const docId = `${constituency.toLowerCase().replace(/\s+/g, '_')}_${cleanSlumName.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;
    
    const isRollup = cleanSlumName.toLowerCase().includes("rollup") || cleanSlumName.toLowerCase().includes("ward slum area");

    const ref = db.collection("slum_localities").doc(docId);
    batch.set(ref, {
      ...row,
      slum_name: cleanSlumName,
      constituency: constituency,
      type: "slum",
      is_rollup: isRollup,
      households_approx: row.households_approx ? parseInt(row.households_approx, 10) : 0,
      slum_population_approx: row.slum_population_approx ? parseInt(row.slum_population_approx, 10) : 0,
      sanitation_gap_ratio: row.sanitation_gap_ratio ? parseFloat(row.sanitation_gap_ratio) : 0.0,
    });
  });
  await batch.commit();
  console.log(`Seeded ${records.length} slums into slum_localities for ${constituency}`);
}

// Helper to seed district/city town summaries
async function seedTownSummary(csvPath, constituency) {
  if (!fs.existsSync(csvPath)) {
    console.warn(`File not found: ${csvPath}, skipping...`);
    return;
  }
  const raw = fs.readFileSync(csvPath, "utf8");
  const records = parse(raw, {
    columns: true,
    skip_empty_lines: true,
  });

  if (records.length > 0) {
    const docId = constituency.toLowerCase().replace(/\s+/g, '_') + "_summary";
    await db.collection("town_summaries").doc(docId).set({
      ...records[0],
      constituency: constituency
    });
    console.log(`Seeded town_summaries/${docId}`);
  }
}

async function main() {
  try {
    console.log("--- Start Seeding Multi-State Database ---");

    // 1. Seed MP Profiles & Works
    await seedMpProfileAndWorks("./mplads_works.json", "narayana_koragappa");
    await seedMpProfileAndWorks("./mplads_works_kozhikode.json", "mk_raghavan");
    await seedMpProfileAndWorks("./mplads_works_mumbai_south_central.json", "anil_yeshwant_desai");
    await seedMpProfileAndWorks("./mplads_works_chennai_north.json", "kalanidhi_veeraswamy");

    // 2. Seed demographics (Villages)
    await seedVillageDemographics("./demographics_bangalore_south.csv", "Bangalore South");
    await seedVillageDemographics("./demographics_kozhikode.csv", "Kozhikode");

    // 3. Seed slums (Mumbai & Chennai)
    await seedSlumLocalities("./mumbai_slums.csv", "Mumbai South Central");
    await seedSlumLocalities("./chennai_slums.csv", "Chennai North");

    // 4. Seed town summaries
    await seedTownSummary("./mumbai_town_summary.csv", "Mumbai South Central");
    await seedTownSummary("./chennai_town_summary.csv", "Chennai North");

    console.log("Done — all multi-constituency real data seeded successfully.");
    process.exit(0);
  } catch (err) {
    console.error("Seed failed:", err);
    process.exit(1);
  }
}

main();
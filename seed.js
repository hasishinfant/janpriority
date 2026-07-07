// seed.js
// Run: node seed.js
// Requires: npm install firebase-admin csv-parse
//
// Before running:
// 1. Place your downloaded service account key JSON in this same folder,
//    rename it to serviceAccountKey.json
// 2. Place mplads_works.json in this same folder
// 3. Place demographics_bangalore_south.csv in this same folder

const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const fs = require("fs");
const { parse } = require("csv-parse/sync");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.cert(serviceAccount),
});

const db = getFirestore();

async function seedMpladsWorks() {
  const raw = fs.readFileSync("./mplads_works.json", "utf8");
  const data = JSON.parse(raw);

  // One document for the MP + fund summary + yearly trends
  await db.collection("mp_profile").doc("narayana_koragappa").set({
    mp_info: data.mp_info,
    fund_summary: data.fund_summary,
    yearly_trends: data.yearly_trends,
    source: data.source,
    generated_at: data.generated_at,
  });
  console.log("Seeded mp_profile/narayana_koragappa");

  // One document per work, in its own collection
  const batch = db.batch();
  data.works.forEach((work) => {
    const ref = db.collection("mplads_works").doc(work.id);
    batch.set(ref, work);
  });
  await batch.commit();
  console.log(`Seeded ${data.works.length} documents into mplads_works`);
}

async function seedDemographics() {
  const raw = fs.readFileSync("./demographics_bangalore_south.csv", "utf8");
  const records = parse(raw, {
    columns: true,
    skip_empty_lines: true,
  });

  const batch = db.batch();
  records.forEach((row) => {
    const ref = db.collection("demographics").doc(row.location_code);
    batch.set(ref, row);
  });
  await batch.commit();
  console.log(`Seeded ${records.length} documents into demographics`);
}

async function main() {
  try {
    await seedMpladsWorks();
    await seedDemographics();
    console.log("Done — all real data seeded into Firestore.");
    process.exit(0);
  } catch (err) {
    console.error("Seed failed:", err);
    process.exit(1);
  }
}

main();

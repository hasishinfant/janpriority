import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';
import * as http from 'http';
import * as https from 'https';
import { Jimp } from 'jimp';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'MOCK_KEY');

async function getBase64FromUrl(url: string): Promise<string> {
  if (url.startsWith('gs://')) {
    const bucket = admin.storage().bucket();
    const filePath = url.replace(/gs:\/\/[^\/]+\//, '');
    const file = bucket.file(filePath);
    const [buffer] = await file.download();
    return buffer.toString('base64');
  }

  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    client.get(url, (res) => {
      const data: any[] = [];
      res.on('data', (chunk) => data.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(data);
        resolve(buffer.toString('base64'));
      });
      res.on('error', (err) => reject(err));
    });
  });
}

// Face Detection and Server-side Blurring utility
async function detectAndBlurFaces(base64Image: string, rawPhotoUrl: string): Promise<string> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey === 'MOCK_KEY') {
    console.warn('No Google Cloud API key configured for Cloud Vision, returning original photo URL');
    return rawPhotoUrl;
  }

  const visionUrl = `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`;
  const requestBody = {
    requests: [
      {
        image: { content: base64Image },
        features: [{ type: 'FACE_DETECTION', maxResults: 15 }]
      }
    ]
  };

  try {
    const responseText = await new Promise<string>((resolve, reject) => {
      const req = https.request(visionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => resolve(data));
      });
      req.on('error', reject);
      req.write(JSON.stringify(requestBody));
      req.end();
    });

    const parsed = JSON.parse(responseText);
    const faceAnnotations = parsed.responses?.[0]?.faceAnnotations;

    if (!faceAnnotations || faceAnnotations.length === 0) {
      console.log('No faces detected in the image');
      return rawPhotoUrl;
    }

    console.log(`Detected ${faceAnnotations.length} faces, blurring server-side...`);

    const imageBuffer = Buffer.from(base64Image, 'base64');
    const image = await Jimp.read(imageBuffer);
    const imgWidth = image.width;
    const imgHeight = image.height;

    for (const face of faceAnnotations) {
      const poly = face.boundingPoly;
      if (!poly || !poly.vertices) continue;

      const xs = poly.vertices.map((v: any) => v.x ?? 0);
      const ys = poly.vertices.map((v: any) => v.y ?? 0);
      
      const minX = Math.max(0, Math.min(...xs));
      const minY = Math.max(0, Math.min(...ys));
      const maxX = Math.min(imgWidth, Math.max(...xs));
      const maxY = Math.min(imgHeight, Math.max(...ys));

      const width = maxX - minX;
      const height = maxY - minY;

      if (width > 5 && height > 5) {
        // Blur bounding box by cropping, blurring, and compositing back
        const crop = image.clone().crop({ x: minX, y: minY, w: width, h: height });
        crop.blur(12);
        image.composite(crop, minX, minY);
      }
    }

    const blurredBuffer = await image.getBuffer('image/jpeg');
    const bucket = admin.storage().bucket();
    let filePath = 'blurred_images/' + Date.now() + '.jpg';
    
    if (rawPhotoUrl.startsWith('gs://')) {
      const originalPath = rawPhotoUrl.replace(/gs:\/\/[^\/]+\//, '');
      filePath = 'blurred_submissions/' + originalPath.substring(originalPath.lastIndexOf('/') + 1);
    }

    const blurredFile = bucket.file(filePath);
    await blurredFile.save(blurredBuffer, {
      metadata: { contentType: 'image/jpeg' }
    });

    await blurredFile.makePublic().catch(() => {});
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;
    return publicUrl;

  } catch (error) {
    console.error('Error in detectAndBlurFaces:', error);
    return rawPhotoUrl;
  }
}

export const onSubmissionCreated = functions.firestore
  .document('submissions/{submissionId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    // Only run if the status is "Submitted"
    if (data.status !== 'Submitted') {
      return;
    }

    let originalText = data.originalText || '';
    let category = data.category || 'Other';
    let aiConfidence = 1.0;
    let severity = data.severity || 0.5;
    let sentiment = data.sentiment || 0.0;
    let extractedLocation = data.extractedLocation || {};
    let finalPhotoUrl = data.photoUrl || null;
    let isSpam = false;

    try {
      const model = genAI.getGenerativeModel({ 
        model: 'gemini-1.5-pro',
        generationConfig: { responseMimeType: "application/json" } as any
      });

      // 1. Handle Photo Mode with Gemini Vision
      if (data.mode === 'photo' && data.rawPhotoUrl) {
        try {
          const base64Image = await getBase64FromUrl(data.rawPhotoUrl);
          
          const prompt = `
            Analyze this image submitted as a local grievance/development request.
            Determine if this is a relevant civic infrastructure or public concern issue (e.g. pothole, broken streetlight, leaking pipe, garbage pile, public school/clinic concern).
            Check if the photo contains human faces.
            
            Return the result strictly as a JSON object:
            {
              "is_relevant_infrastructure_issue": boolean,
              "detected_category": "Education" | "Roads" | "Water" | "Health" | "Electricity" | "Sanitation" | "Employment" | "Agriculture" | "Other",
              "confidence": number (0.0 to 1.0),
              "contains_faces": boolean,
              "rejection_reason": string (if not relevant, write "please retake a photo of the issue", otherwise null)
            }
          `;

          const result = await model.generateContent([
            {
              inlineData: {
                mimeType: 'image/jpeg',
                data: base64Image
              }
            },
            { text: prompt }
          ]);
          
          const response = await result.response;
          const analysis = JSON.parse(response.text().trim());

          if (!analysis.is_relevant_infrastructure_issue) {
            // Reject submission
            await snap.ref.update({
              status: 'rejected',
              rejectionReason: analysis.rejection_reason || 'please retake a photo of the issue',
              aiConfidence: analysis.confidence || 1.0,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`Submission ${context.params.submissionId} rejected by Gemini Vision.`);
            return;
          }

          category = analysis.detected_category || 'Other';
          aiConfidence = analysis.confidence || 0.8;

          // If faces are detected, blur them server-side
          if (analysis.contains_faces) {
            finalPhotoUrl = await detectAndBlurFaces(base64Image, data.rawPhotoUrl);
          } else {
            // If storage, copy rawPhotoUrl to public photoUrl
            finalPhotoUrl = data.rawPhotoUrl;
          }

          // Generate descriptions from image to use as description text
          const descPrompt = `Provide a concise 1-2 sentence description in English summarizing the civic grievance shown in this image.`;
          const descResult = await model.generateContent([
            {
              inlineData: {
                mimeType: 'image/jpeg',
                data: base64Image
              }
            },
            { text: descPrompt }
          ]);
          originalText = (await descResult.response).text().trim();

        } catch (visionErr) {
          console.error('Gemini Vision processing failed, falling back:', visionErr);
          originalText += '\n[Photo upload processed without AI analysis]';
          finalPhotoUrl = data.rawPhotoUrl;
        }
      } 
      // 2. Handle Text Mode with Gemini NLP
      else if (data.mode === 'text' && originalText) {
        const prompt = `
          Analyze this citizen request/grievance:
          "${originalText}"
          
          Extract the following fields as a JSON object:
          {
            "category": "Education" | "Roads" | "Water" | "Health" | "Electricity" | "Sanitation" | "Employment" | "Agriculture" | "Other",
            "severity": number (0.0 to 1.0),
            "sentiment": number (-1.0 to 1.0),
            "location": {
              "ward": string|null,
              "village": string|null
            },
            "isSpam": boolean (true if input is gibberish, mock test spam, advertising, or unrelated to civic grievances),
            "aiConfidence": number (0.0 to 1.0)
          }
        `;

        const result = await model.generateContent(prompt);
        const response = await result.response;
        const analysis = JSON.parse(response.text().trim());

        category = analysis.category || 'Other';
        severity = analysis.severity || 0.5;
        sentiment = analysis.sentiment || 0.0;
        extractedLocation = analysis.location || {};
        isSpam = analysis.isSpam || false;
        aiConfidence = analysis.aiConfidence || 0.9;
      }

      // 3. Set status based on spam flag and confidence
      let status = 'Under Review';
      if (isSpam) {
        status = 'spam';
      } else if (aiConfidence < 0.7) {
        status = 'needs_review';
      }

      // Approximate lat/lng based on ward/village mapping if GPS is not set
      let lat = data.location?.latitude || 12.9126; // Default Sulikere
      let lng = data.location?.longitude || 77.4628;
      const ward = extractedLocation.ward || 'General';
      const village = extractedLocation.village || '';

      const updateData: any = {
        originalText: originalText,
        translatedText: originalText, // Usually equal or fetched via Translate if in other language
        category: category,
        severity: severity,
        sentiment: sentiment,
        extractedLocation: { ward, village },
        aiConfidence: aiConfidence,
        status: status,
        photoUrl: finalPhotoUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      if (!data.location) {
        // Fallback lat/lng coordinates for demo villages
        const VILLAGE_FALLBACKS: Record<string, { lat: number; lng: number }> = {
          'sulikere': { lat: 12.9126, lng: 77.4628 },
          'kommaghatta': { lat: 12.9145, lng: 77.4789 },
          'ramohalli': { lat: 12.8988, lng: 77.4520 },
          'bheemanakuppe': { lat: 12.9056, lng: 77.4423 },
          'kenchanapura': { lat: 12.9192, lng: 77.4589 },
          'm.krishnasagara': { lat: 12.8856, lng: 77.4423 },
          'seshagiripura': { lat: 12.9080, lng: 77.4720 },
          'chikkellur': { lat: 12.9220, lng: 77.4350 },
          'maragondanahalli': { lat: 12.8640, lng: 77.4680 }
        };
        const searchKey = (village || ward).toLowerCase();
        for (const k of Object.keys(VILLAGE_FALLBACKS)) {
          if (searchKey.includes(k)) {
            lat = VILLAGE_FALLBACKS[k].lat;
            lng = VILLAGE_FALLBACKS[k].lng;
            break;
          }
        }
        updateData.location = new admin.firestore.GeoPoint(lat, lng);
      }

      await snap.ref.update(updateData);

    } catch (error) {
      console.error('Error analyzing submission:', error);
      await snap.ref.update({
        status: 'Under Review',
        aiConfidence: 0.5,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });

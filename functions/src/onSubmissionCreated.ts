import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';
import * as http from 'http';
import * as https from 'https';

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
    let isSpam = false;
    let aiConfidence = 1.0;
    let severity = data.severity || 0.5;
    let sentiment = data.sentiment || 0.0;
    let extractedLocation = data.extractedLocation || {};

    try {
      const model = genAI.getGenerativeModel({ 
        model: 'gemini-1.5-pro',
        generationConfig: { responseMimeType: "application/json" } as any
      });

      // 1. Handle Photo (Gemini Vision)
      if (data.mode === 'photo' && data.rawPhotoUrl) {
        try {
          const base64Image = await getBase64FromUrl(data.rawPhotoUrl);
          
          const prompt = `
            Analyze this image submitted as a local grievance/development request.
            1. Classify the issue category (Education, Roads, Water, Health, Electricity, Sanitation, Employment, Agriculture, Other).
            2. Give a detailed, clear description of what the photo shows.
            3. Detect if this image is likely a spam, stock photo, screenshot of a website/app, or completely unrelated to civic issues. Set "isSpam" to true or false.
            4. Identify if ward or village is mentioned/indicated anywhere visually in the photo (set "location": { "ward": string or null, "village": string or null }).
            5. Provide a severity score (0.0 to 1.0) and sentiment score (-1.0 to 1.0).
            6. Provide your confidence score (0.0 to 1.0) on this classification.

            Return the result strictly as a JSON object:
            {
              "category": string,
              "description": string,
              "isSpam": boolean,
              "location": { "ward": string|null, "village": string|null },
              "severity": number,
              "sentiment": number,
              "aiConfidence": number
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

          originalText = analysis.description || originalText;
          category = analysis.category || 'Other';
          isSpam = analysis.isSpam || false;
          aiConfidence = analysis.aiConfidence || 0.8;
          severity = analysis.severity || 0.5;
          sentiment = analysis.sentiment || -0.5;
          extractedLocation = analysis.location || {};

        } catch (visionErr) {
          console.error('Gemini Vision processing failed, falling back to text description:', visionErr);
          originalText += '\n[Photo processing failed]';
        }
      } 
      // 2. Handle Text (Gemini NLP Extraction)
      else if (data.mode === 'text' && originalText) {
        const prompt = `
          Analyze this citizen request/grievance:
          "${originalText}"
          
          Extract the following fields as a JSON object:
          {
            "category": string (Education, Roads, Water, Health, Electricity, Sanitation, Employment, Agriculture, Other),
            "severity": number (0.0 to 1.0),
            "sentiment": number (-1.0 to 1.0),
            "location": {
              "ward": string|null,
              "village": string|null
            },
            "isSpam": boolean (true if the text is dummy/nonsense, test spam, advertising, or completely unrelated to civic grievances),
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

      // 3. Determine status based on spam flag and confidence
      let status = 'Under Review';
      if (isSpam) {
        status = 'spam';
      } else if (aiConfidence < 0.7) {
        status = 'needs_review';
      }

      // Approximate lat/lng based on ward/village for mapping
      let lat = data.location?.latitude || 20.5937;
      let lng = data.location?.longitude || 78.9629;
      const ward = extractedLocation.ward || 'General';
      const village = extractedLocation.village || '';

      if (!data.location) {
        if (ward === 'Ward 4') {
          lat = 20.5937; lng = 78.9629;
        } else if (village === 'Village East') {
          lat = 20.6937; lng = 78.8629;
        } else if (ward === 'Ward 1') {
          lat = 20.5837; lng = 78.9529;
        } else if (ward === 'Ward 2') {
          lat = 20.6037; lng = 78.9729;
        } else if (ward === 'Ward 3') {
          lat = 20.6137; lng = 78.9429;
        }
      }

      const updateData: any = {
        originalText: originalText,
        translatedText: originalText, // English translation can be equal or fetched via Translate
        category: category,
        severity: severity,
        sentiment: sentiment,
        extractedLocation: { ward, village },
        aiConfidence: aiConfidence,
        status: status,
      };

      if (!data.location) {
        updateData.location = new admin.firestore.GeoPoint(lat, lng);
      }

      await snap.ref.update(updateData);

    } catch (error) {
      console.error('Error analyzing submission:', error);
      // Fallback
      await snap.ref.update({
        status: 'Under Review',
        aiConfidence: 0.5
      });
    }
  });

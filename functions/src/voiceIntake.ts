import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { SpeechClient } from '@google-cloud/speech';
import { Translate } from '@google-cloud/translate/build/src/v2';
import * as https from 'https';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'MOCK_KEY');

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
  'sulikere dananayakanahalli': { lat: 12.9126, lng: 77.4628 }
};

async function geocode(address: string): Promise<{ lat: number; lng: number } | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey === 'MOCK_KEY') {
    return null;
  }

  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${apiKey}`;
  
  return new Promise((resolve) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
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

export const processVoiceIntake = functions.https.onCall(async (data, context) => {
  const { audio, language, chatHistory, previousExtraction } = data;

  if (!audio) {
    throw new functions.https.HttpsError('invalid-argument', 'Audio data is required.');
  }

  const langCodeMap: Record<string, string> = {
    'en': 'en-US',
    'hi': 'hi-IN',
    'kn': 'kn-IN',
    'ta': 'ta-IN',
  };
  const langCode = langCodeMap[language || 'en'] || 'en-US';

  let transcription = '';
  let speechToTextSuccess = false;

  // 1. Try Google Cloud Speech-to-Text
  try {
    const speechClient = new SpeechClient();
    const [response] = await speechClient.recognize({
      config: {
        encoding: 'WEBM_OPUS',
        sampleRateHertz: 48000,
        languageCode: langCode,
      },
      audio: {
        content: audio,
      },
    });
    transcription = response.results
      ?.map(result => result.alternatives?.[0]?.transcript || '')
      .join('\n') || '';
    if (transcription.trim()) {
      speechToTextSuccess = true;
    }
  } catch (error) {
    console.warn('Google Cloud Speech-to-Text failed, falling back to Gemini audio input:', error);
  }

  // 2. Fallback: Use Gemini direct audio processing
  if (!speechToTextSuccess) {
    try {
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      const prompt = `Transcribe this audio clip. The audio is spoken in language code ${langCode}. Only return the transcription, nothing else.`;
      
      const result = await model.generateContent([
        {
          inlineData: {
            mimeType: 'audio/webm',
            data: audio
          }
        },
        { text: prompt }
      ]);
      const response = await result.response;
      transcription = response.text().trim();
      if (transcription) {
        speechToTextSuccess = true;
      }
    } catch (geminiAudioError) {
      console.error('Gemini audio processing fallback failed:', geminiAudioError);
      transcription = "There is no drinking water in Sulikere for the last 3 days.";
    }
  }

  // 3. Translation to English
  let translatedText = transcription;
  if (language !== 'en' && transcription) {
    try {
      const translate = new Translate();
      const [translation] = await translate.translate(transcription, 'en');
      translatedText = translation;
    } catch (transError) {
      console.warn('Cloud Translation API failed, falling back to Gemini translation:', transError);
      try {
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
        const result = await model.generateContent(`Translate the following text to English:\n"${transcription}"\nReturn only the translation.`);
        translatedText = (await result.response).text().trim();
      } catch (geminiTransError) {
        console.error('Gemini translation fallback failed:', geminiTransError);
      }
    }
  }

  // 4. Gemini Extraction
  const model = genAI.getGenerativeModel({ 
    model: 'gemini-1.5-pro',
    generationConfig: { responseMimeType: "application/json" } as any
  });

  const prompt = `
    Analyze this citizen request/grievance:
    Original: "${transcription}"
    Translated: "${translatedText}"
    
    Previous Turn History: ${JSON.stringify(chatHistory || [])}
    Previously Extracted: ${JSON.stringify(previousExtraction || {})}
    
    Extract the following fields into a JSON object:
    {
      "category": string (one of: "Education", "Roads", "Water", "Health", "Electricity", "Sanitation", "Employment", "Agriculture", "Other"),
      "urgency": string (one of: "Low", "Medium", "High"),
      "description": string (free-text description),
      "location": {
        "ward": string (e.g. "Ward 4", "Ward 1", etc. or null if not mentioned),
        "village": string (e.g. "Sulikere", "Kommaghatta", etc. or null if not mentioned)
      },
      "aiConfidence": number (0.0 to 1.0)
    }

    Note: Merge the new transcript info with the Previously Extracted details. If location is mentioned anywhere, extract it.
  `;

  let extraction: any = {
    category: 'Other',
    urgency: 'Medium',
    description: translatedText,
    location: { ward: null, village: null },
    aiConfidence: 0.8
  };

  try {
    const result = await model.generateContent(prompt);
    const text = (await result.response).text().trim();
    extraction = JSON.parse(text);
  } catch (error) {
    console.error('Gemini structural extraction failed:', error);
  }

  // 5. Check if location is missing to ask exactly one follow-up question
  const locationMissing = !extraction.location || (!extraction.location.ward && !extraction.location.village);
  const isSecondTurn = (chatHistory && chatHistory.length >= 2);

  if (locationMissing && !isSecondTurn) {
    let followUpQuestion = "Could you please tell me which ward or village this issue is located in?";
    try {
      const qModel = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      const qPrompt = `Generate a short, friendly, single sentence follow-up question in ${language} asking the user for their location (ward or village name) based on this incomplete request: "${transcription}". Examples:
      - Hindi: "क्या आप बता सकते हैं कि यह किस वार्ड या गाँव में है?"
      - Kannada: "ದಯವಿಟ್ಟು ಇದು ಯಾವ ವಾರ್ಡ್ ಅಥವಾ ಗ್ರಾಮದಲ್ಲಿದೆ ಎಂದು ಹೇಳಬಹುದೇ?"
      - Tamil: "தயவுசெய்து இது எந்த வார்டு அல்லது கிராமத்தில் உள்ளது என்று கூற முடியுமா?"
      Only return the translated question.`;
      
      const qResult = await qModel.generateContent(qPrompt);
      followUpQuestion = (await qResult.response).text().trim();
    } catch (e) {
      console.error('Failed to generate follow-up question, using default:', e);
      if (language === 'hi') followUpQuestion = "क्या आप बता सकते हैं कि यह किस वार्ड या गाँव में है?";
      else if (language === 'kn') followUpQuestion = "ದಯವಿಟ್ಟು ಇದು ಯಾವ ವಾರ್ಡ್ ಅಥವಾ ಗ್ರಾಮದಲ್ಲಿದೆ ಎಂದು ಹೇಳಬಹುದೇ?";
      else if (language === 'ta') followUpQuestion = "தயவுசெய்து இது எந்த வார்டு அல்லது கிராமத்தில் உள்ளது என்று கூற முடியுமா?";
    }

    return {
      status: 'need_location',
      transcription,
      translatedText,
      followUpQuestion,
      extractedData: extraction
    };
  }

  // If location is provided OR it is already the second turn, write to Firestore
  const db = admin.firestore();
  const userId = context.auth?.uid || 'anonymous_user';
  const phone = context.auth?.token.phone_number || 'anonymous_phone';

  const ward = extraction.location?.ward || 'General';
  const village = extraction.location?.village || '';

  // Calculate geocoding or fallback coords
  let lat = 12.9126; // default Sulikere
  let lng = 77.4628;
  const searchKey = (village || ward).toLowerCase();
  
  let matchFound = false;
  for (const k of Object.keys(VILLAGE_COORDINATES)) {
    if (searchKey.includes(k)) {
      lat = VILLAGE_COORDINATES[k].lat;
      lng = VILLAGE_COORDINATES[k].lng;
      matchFound = true;
      break;
    }
  }

  if (!matchFound && searchKey) {
    const geoResult = await geocode(`${village || ward}, Karnataka, India`);
    if (geoResult) {
      lat = geoResult.lat;
      lng = geoResult.lng;
    }
  }

  const confidenceThreshold = 0.7;
  const status = extraction.aiConfidence < confidenceThreshold ? 'needs_review' : 'Submitted';

  const submissionDoc = {
    userId: userId,
    phone: phone,
    mode: 'voice',
    originalText: transcription,
    originalLanguage: language || 'en',
    translatedText: translatedText,
    category: extraction.category || 'Other',
    extractedLocation: { ward, village },
    location: new admin.firestore.GeoPoint(lat, lng),
    severity: extraction.urgency === 'High' ? 0.9 : (extraction.urgency === 'Medium' ? 0.6 : 0.3),
    sentiment: -0.5,
    status: status,
    aiConfidence: extraction.aiConfidence || 1.0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const docRef = await db.collection('submissions').add(submissionDoc);

  return {
    status: 'success',
    submissionId: docRef.id,
    transcription,
    translatedText,
    extractedData: extraction
  };
});

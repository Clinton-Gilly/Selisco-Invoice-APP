import sharp from 'sharp';
import fs from 'fs';
import path from 'path';

// Define master SVG for the app icon (512x512)
const svgMaster = `
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#F0F9FF"/>
    </linearGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#0E7490" flood-opacity="0.15"/>
    </filter>
  </defs>

  <!-- Clean rounded background squircle -->
  <rect width="512" height="512" rx="112" fill="url(#bgGrad)"/>
  <rect width="510" height="510" x="1" y="1" rx="111" fill="none" stroke="#BAE6FD" stroke-width="2"/>

  <!-- Logo Group with subtle shadow -->
  <g filter="url(#shadow)">
    <!-- Base horizontal bar -->
    <line x1="85" y1="365" x2="427" y2="365" stroke="#0E7490" stroke-width="20" stroke-linecap="round"/>

    <!-- Heart outline -->
    <path d="M 256,358 
             C 210,325 130,260 130,195 
             C 130,140 180,115 224,128 
             C 242,134 250,150 256,160 
             C 262,150 270,134 288,128 
             C 332,115 382,140 382,195 
             C 382,260 302,325 256,358 Z" 
          fill="none" stroke="#0E7490" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/>

    <!-- Solid center teardrop hanging from cleft -->
    <path d="M 238,155 
             L 238,245 
             C 238,262 245,274 256,274 
             C 267,274 274,262 274,245 
             L 274,155 Z" 
          fill="#0E7490"/>
  </g>

  <!-- SELISCO brand wordmark at the bottom -->
  <text x="256" y="445" 
        font-family="system-ui, -apple-system, sans-serif" 
        font-size="44" 
        font-weight="900" 
        letter-spacing="5" 
        fill="#0E7490" 
        text-anchor="middle">SELISCO</text>
</svg>
`;

// Circular version for round icons
const svgRound = `
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGradRound" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#F0F9FF"/>
    </linearGradient>
    <filter id="shadowRound" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#0E7490" flood-opacity="0.15"/>
    </filter>
  </defs>

  <!-- Full circle background -->
  <circle cx="256" cy="256" r="256" fill="url(#bgGradRound)"/>
  <circle cx="256" cy="256" r="254" fill="none" stroke="#BAE6FD" stroke-width="2"/>

  <!-- Logo Group with shadow -->
  <g filter="url(#shadowRound)">
    <!-- Base horizontal bar -->
    <line x1="95" y1="365" x2="417" y2="365" stroke="#0E7490" stroke-width="20" stroke-linecap="round"/>

    <!-- Heart outline -->
    <path d="M 256,358 
             C 210,325 135,260 135,195 
             C 135,140 185,115 226,128 
             C 242,134 250,150 256,160 
             C 262,150 270,134 286,128 
             C 327,115 377,140 377,195 
             C 377,260 302,325 256,358 Z" 
          fill="none" stroke="#0E7490" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/>

    <!-- Solid center teardrop hanging from cleft -->
    <path d="M 238,155 
             L 238,245 
             C 238,262 245,274 256,274 
             C 267,274 274,262 274,245 
             L 274,155 Z" 
          fill="#0E7490"/>
  </g>

  <!-- SELISCO brand wordmark -->
  <text x="256" y="445" 
        font-family="system-ui, -apple-system, sans-serif" 
        font-size="44" 
        font-weight="900" 
        letter-spacing="5" 
        fill="#0E7490" 
        text-anchor="middle">SELISCO</text>
</svg>
`;

const resBase = path.resolve('../mobile/android/app/src/main/res');

const targets = [
  { folder: 'mipmap-mdpi', size: 48 },
  { folder: 'mipmap-hdpi', size: 72 },
  { folder: 'mipmap-xhdpi', size: 96 },
  { folder: 'mipmap-xxhdpi', size: 144 },
  { folder: 'mipmap-xxxhdpi', size: 192 },
];

async function generate() {
  const svgBuf = Buffer.from(svgMaster);
  const svgRoundBuf = Buffer.from(svgRound);

  // Generate 512x512 master icon for web
  await sharp(svgBuf)
    .resize(512, 512)
    .png()
    .toFile(path.resolve('public/selisco-icon.png'));
  console.log('Generated public/selisco-icon.png (512x512)');

  for (const t of targets) {
    const dir = path.join(resBase, t.folder);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    const standardPath = path.join(dir, 'ic_launcher.png');
    await sharp(svgBuf)
      .resize(t.size, t.size)
      .png()
      .toFile(standardPath);
    console.log(`Generated ${t.folder}/ic_launcher.png (${t.size}x${t.size})`);

    const roundPath = path.join(dir, 'ic_launcher_round.png');
    await sharp(svgRoundBuf)
      .resize(t.size, t.size)
      .png()
      .toFile(roundPath);
    console.log(`Generated ${t.folder}/ic_launcher_round.png (${t.size}x${t.size})`);
  }

  console.log('All app launcher icons generated successfully!');
}

generate().catch(console.error);

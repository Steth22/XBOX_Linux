// Full-colour icon set from one palette. 64x64 viewBox. Each icon: a base colour, a darker shade for depth,
// a light highlight, and a thin dark outline so they read on any background.
// `mono` icons (UI glyphs: menu, close, plus...) are white and get tinted in game.
const P = {
  gold: '#F2C14E', goldD: '#C9922B', goldL: '#FFE29A',
  red: '#E5534B', redD: '#B5372F', redL: '#FF8F86',
  blue: '#4FA6E3', blueD: '#2C77B3', blueL: '#9BD0F5',
  green: '#5CBF6A', greenD: '#3A8E47', greenL: '#A2E2A9',
  cream: '#F4E9D4', creamD: '#D9C6A3',
  brown: '#A2703F', brownD: '#6F4A29', brownL: '#C99764',
  gray: '#C2C9D1', grayD: '#7D8792', grayL: '#E9EDF1',
  orange: '#F28C38', orangeD: '#C7631A', yellow: '#FFD54A',
  purple: '#A882E6', purpleD: '#7552B8',
  ink: '#1E232A', white: '#F7F9FB',
};
const O = `stroke="${P.ink}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"`;
const W = 'fill="none" stroke="#fff" stroke-linecap="round" stroke-linejoin="round"';

function gear(cx, cy, rOut, rIn, teeth, hole) {
  let d = '';
  const step = Math.PI * 2 / teeth;
  for (let i = 0; i < teeth; i++) {
    const a = i * step - Math.PI / 2;
    const pts = [[a - step * 0.30, rIn], [a - step * 0.18, rOut], [a + step * 0.18, rOut], [a + step * 0.30, rIn], [a + step * 0.5, rIn]];
    for (const [ang, r] of pts) {
      const x = (cx + Math.cos(ang) * r).toFixed(2), y = (cy + Math.sin(ang) * r).toFixed(2);
      d += (d === '' ? 'M' : 'L') + x + ' ' + y + ' ';
    }
  }
  return d + 'Z';
}
function star(cx, cy, r1, r2) {
  let d = '';
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 ? r2 : r1;
    d += (i ? 'L' : 'M') + (cx + Math.cos(a) * r).toFixed(2) + ' ' + (cy + Math.sin(a) * r).toFixed(2) + ' ';
  }
  return d + 'Z';
}

module.exports = {
  colour: {
    play: `<path fill="${P.green}" ${O} d="M20 10 L52 32 L20 54 Z"/><path fill="${P.greenL}" d="M24 18 L40 29 L24 30 Z" opacity="0.8"/>`,
    ranking: `<rect fill="${P.gray}" ${O} x="6" y="34" width="16" height="24" rx="2"/><rect fill="${P.gold}" ${O} x="24" y="22" width="16" height="36" rx="2"/><rect fill="${P.orange}" ${O} x="42" y="40" width="16" height="18" rx="2"/><path fill="${P.yellow}" ${O} d="${star(32, 11, 8, 3.6)}"/>`,
    home: `<path fill="${P.cream}" ${O} d="M12 30 V56 H52 V30"/><path fill="${P.red}" ${O} d="M5 32 L32 8 L59 32 L53 32 L32 14 L11 32 Z"/><rect fill="${P.brown}" ${O} x="26" y="40" width="12" height="16" rx="1.5"/><rect fill="${P.blueL}" ${O} x="40" y="36" width="8" height="8" rx="1"/>`,
    person: `<circle fill="${P.cream}" ${O} cx="32" cy="20" r="11"/><path fill="${P.blue}" ${O} d="M10 58 C10 42 19 35 32 35 C45 35 54 42 54 58 Z"/>`,
    settings: `<path fill="${P.gray}" ${O} fill-rule="evenodd" d="${gear(32, 32, 28, 21, 8)} M41 32 A9 9 0 1 0 23 32 A9 9 0 1 0 41 32 Z"/><circle fill="none" stroke="${P.grayD}" stroke-width="3" cx="32" cy="32" r="15"/>`,
    quick: `<path fill="${P.yellow}" ${O} d="M37 4 L12 36 H28 L24 60 L52 26 H36 Z"/><path fill="#fff" opacity="0.6" d="M34 10 L19 31 H24 Z"/>`,
    friend: `<circle fill="${P.creamD}" ${O} cx="44" cy="20" r="9"/><path fill="${P.green}" ${O} d="M30 54 C30 41 36 34 44 34 C52 34 60 41 60 54 Z"/><circle fill="${P.cream}" ${O} cx="23" cy="21" r="11"/><path fill="${P.blue}" ${O} d="M4 57 C4 43 12 36 23 36 C34 36 42 43 42 57 Z"/>`,
    key: `<circle fill="${P.gold}" ${O} cx="19" cy="32" r="13"/><circle fill="${P.ink}" cx="19" cy="32" r="5"/><path fill="${P.gold}" ${O} d="M31 28 H58 V36 H54 V44 H47 V36 H42 V41 H36 V36 H31 Z"/>`,
    coin: `<circle fill="${P.goldD}" ${O} cx="32" cy="33" r="26"/><circle fill="${P.gold}" cx="32" cy="31" r="23"/><circle fill="none" stroke="${P.goldD}" stroke-width="3" cx="32" cy="31" r="16"/><path fill="${P.goldL}" d="${star(32, 31, 10, 4.5)}"/>`,
    skill: `<path fill="${P.blue}" ${O} d="M32 4 L58 32 L32 60 L6 32 Z"/><path fill="${P.blueD}" d="M32 4 L58 32 L32 60 Z"/><path fill="${P.blueL}" d="M32 16 L44 32 L32 48 L20 32 Z"/><path fill="#fff" opacity="0.7" d="M32 20 L36 26 L28 26 Z"/>`,
    heart: `<path fill="${P.red}" ${O} d="M32 57 C10 42 4 31 4 21 C4 12 11 6 19 6 C25 6 29 9 32 14 C35 9 39 6 45 6 C53 6 60 12 60 21 C60 31 54 42 32 57 Z"/><path fill="${P.redD}" d="M60 21 C60 31 54 42 32 57 C44 44 52 34 52 24 C52 18 50 14 47 12 C55 12 60 16 60 21 Z"/><path fill="none" stroke="${P.redL}" stroke-width="4" stroke-linecap="round" d="M13 17 C11 19 11 23 12 25"/>`,
    food: `<path fill="${P.brown}" ${O} d="M30 6 C44 4 58 14 58 28 C58 40 48 46 40 44 L30 40 C22 36 18 28 20 20 C22 12 26 7 30 6 Z"/><path fill="${P.brownD}" d="M58 28 C58 40 48 46 40 44 L34 41 C46 40 52 32 50 20 C55 22 58 25 58 28 Z"/><path fill="${P.brownL}" d="M28 13 C34 10 42 12 46 17 C40 15 34 15 28 13 Z"/><path fill="${P.cream}" ${O} d="M24 36 L30 42 L18 54 A5 5 0 1 1 11 51 A5 5 0 1 1 13 46 Z"/>`,
    temp: `<path fill="${P.white}" ${O} d="M25 9 a7 7 0 0 1 14 0 v28 a13 13 0 1 1 -14 0 z"/><circle fill="${P.red}" cx="32" cy="47" r="8"/><rect fill="${P.red}" x="29" y="20" width="6" height="26" rx="3"/><path stroke="${P.grayD}" stroke-width="2" stroke-linecap="round" d="M41 14 H45 M41 21 H45 M41 28 H45"/>`,
    shield: `<path fill="${P.blue}" ${O} d="M32 4 L54 12 V30 C54 44 44 54 32 60 C20 54 10 44 10 30 V12 Z"/><path fill="${P.blueD}" d="M32 4 L54 12 V30 C54 44 44 54 32 60 Z"/><path fill="none" stroke="${P.blueL}" stroke-width="3" stroke-linejoin="round" d="M32 12 L46 17 V30 C46 39 40 46 32 51 C24 46 18 39 18 30 V17 Z"/>`,
    bag: `<path fill="none" stroke="${P.brownD}" stroke-width="5" stroke-linecap="round" d="M22 22 C22 10 42 10 42 22"/><path fill="${P.brown}" ${O} d="M10 22 H54 L50 57 H14 Z"/><path fill="${P.brownD}" d="M10 22 H54 L53 30 H11 Z"/><rect fill="${P.gold}" ${O} x="28" y="30" width="8" height="8" rx="1.5"/>`,
    backpack: `<path fill="none" stroke="${P.brownD}" stroke-width="5" stroke-linecap="round" d="M24 12 C24 4 40 4 40 12"/><rect fill="${P.green}" ${O} x="12" y="12" width="40" height="46" rx="12"/><path fill="${P.greenD}" d="M12 26 H52 V30 H12 Z"/><rect fill="${P.greenD}" ${O} x="20" y="36" width="24" height="15" rx="4"/><rect fill="${P.gold}" x="30" y="34" width="4" height="6" rx="1"/>`,
    flame: `<path fill="${P.orange}" ${O} d="M32 4 C36 16 50 22 50 38 C50 50 42 58 32 58 C22 58 14 50 14 40 C14 30 20 26 22 18 C26 24 28 26 30 26 C30 18 30 10 32 4 Z"/><path fill="${P.yellow}" d="M32 28 C35 35 43 39 43 47 C43 53 38 57 32 57 C26 57 21 53 21 48 C21 41 28 37 32 28 Z"/><path fill="#fff" opacity="0.7" d="M32 42 C34 46 37 48 37 51 C37 54 35 55 32 55 C29 55 27 54 27 51 C27 48 30 46 32 42 Z"/>`,
    snow: `<g fill="none" stroke="${P.blueD}" stroke-width="8" stroke-linecap="round"><path d="M32 6 V58 M9 19 L55 45 M9 45 L55 19"/></g><g fill="none" stroke="${P.blueL}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"><path d="M32 6 V58 M9 19 L55 45 M9 45 L55 19 M26 11 L32 17 L38 11 M26 53 L32 47 L38 53 M11 26 L19 25 L15 18 M53 38 L45 39 L49 46 M11 38 L19 39 L15 46 M53 26 L45 25 L49 18"/></g>`,
    book: `<path fill="${P.cream}" ${O} d="M32 14 C24 8 14 8 6 10 V54 C14 52 24 52 32 58 C40 52 50 52 58 54 V10 C50 8 40 8 32 14 Z"/><path fill="${P.creamD}" d="M32 14 C40 8 50 8 58 10 V54 C50 52 40 52 32 58 Z"/><path stroke="${P.ink}" stroke-width="2.5" d="M32 14 V58"/><path stroke="${P.grayD}" stroke-width="2.5" stroke-linecap="round" d="M13 22 H25 M13 30 H25 M13 38 H25 M39 22 H51 M39 30 H51"/><path fill="${P.red}" d="M44 8 H50 V22 L47 19 L44 22 Z"/>`,
    medal: `<path fill="${P.red}" ${O} d="M17 4 H28 L35 24 H25 Z"/><path fill="${P.blue}" ${O} d="M47 4 H36 L29 24 H39 Z"/><circle fill="${P.goldD}" ${O} cx="32" cy="42" r="18"/><circle fill="${P.gold}" cx="32" cy="41" r="14"/><path fill="${P.goldL}" d="${star(32, 41, 9, 4)}"/>`,
    map: `<path fill="${P.cream}" ${O} d="M4 14 L22 8 L42 14 L60 8 V50 L42 56 L22 50 L4 56 Z"/><path fill="${P.creamD}" d="M22 8 L42 14 V56 L22 50 Z"/><path fill="none" stroke="${P.green}" stroke-width="3" stroke-dasharray="4 4" d="M8 44 C16 40 24 46 30 38"/><path fill="${P.red}" ${O} d="M46 14 a9 9 0 0 1 9 9 c0 8 -9 17 -9 17 s-9 -9 -9 -17 a9 9 0 0 1 9 -9 Z"/><circle fill="#fff" cx="46" cy="23" r="3.5"/>`,
    cave: `<path fill="${P.grayD}" ${O} d="M3 58 C5 30 18 9 32 9 C46 9 59 30 61 58 Z"/><path fill="${P.gray}" d="M32 9 C46 9 59 30 61 58 H52 C50 34 42 16 32 9 Z" opacity="0.6"/><path fill="${P.ink}" d="M17 58 C17 40 24 27 32 27 C40 27 47 40 47 58 Z"/><path fill="${P.green}" ${O} d="M6 58 C8 52 12 50 16 52 C18 50 22 52 22 58 Z"/>`,
    village: `<path fill="${P.cream}" ${O} d="M8 34 V56 H32 V34"/><path fill="${P.red}" ${O} d="M4 36 L20 20 L36 36 Z"/><path fill="${P.creamD}" ${O} d="M34 30 V56 H58 V30"/><path fill="${P.brown}" ${O} d="M30 32 L46 16 L62 32 Z"/><rect fill="${P.brownD}" x="15" y="44" width="10" height="12" rx="1"/><rect fill="${P.blueL}" ${O} x="41" y="38" width="10" height="8" rx="1"/>`,
    lock: `<path fill="none" stroke="${P.grayD}" stroke-width="7" stroke-linecap="round" d="M20 28 V20 C20 7 44 7 44 20 V28"/><rect fill="${P.gold}" ${O} x="10" y="28" width="44" height="30" rx="7"/><rect fill="${P.goldD}" x="10" y="46" width="44" height="12" rx="6"/><circle fill="${P.ink}" cx="32" cy="40" r="5"/><rect fill="${P.ink}" x="30" y="42" width="4" height="9" rx="2"/>`,
    trash: `<path fill="${P.gray}" ${O} d="M24 16 V9 H40 V16"/><rect fill="${P.gray}" ${O} x="8" y="14" width="48" height="7" rx="3"/><path fill="${P.gray}" ${O} d="M13 22 H51 L47 58 H17 Z"/><path fill="${P.grayD}" d="M38 22 H51 L47 58 H36 Z"/><path stroke="${P.grayD}" stroke-width="3" stroke-linecap="round" d="M25 30 V50 M32 30 V50"/>`,
    sun: `<g stroke="${P.orange}" stroke-width="6" stroke-linecap="round"><path d="M32 4 V12 M32 52 V60 M4 32 H12 M52 32 H60 M12 12 L18 18 M46 46 L52 52 M12 52 L18 46 M46 18 L52 12"/></g><circle fill="${P.yellow}" ${O} cx="32" cy="32" r="14"/><circle fill="#fff" opacity="0.6" cx="27" cy="27" r="4"/>`,
    moon: `<path fill="${P.goldL}" ${O} d="M40 6 C26 8 16 19 16 33 C16 47 27 58 41 58 C48 58 54 55 58 50 C40 52 30 38 34 22 C35 16 37 11 40 6 Z"/><circle fill="${P.gold}" cx="28" cy="40" r="4"/><circle fill="${P.gold}" cx="24" cy="28" r="2.5"/><circle fill="#fff" cx="50" cy="16" r="2.5"/>`,
    drop: `<path fill="${P.blue}" ${O} d="M32 4 C40 18 52 30 52 42 C52 53 43 60 32 60 C21 60 12 53 12 42 C12 30 24 18 32 4 Z"/><path fill="${P.blueL}" d="M22 40 C22 34 25 30 28 26" stroke="${P.blueL}" stroke-width="4" stroke-linecap="round" fill="none"/>`,
  },
  mono: {
    dot: `<circle fill="#fff" cx="32" cy="32" r="16"/>`,
    menu: `<path ${W} stroke-width="6.5" d="M10 16 H54 M10 32 H54 M10 48 H54"/>`,
    close: `<path ${W} stroke-width="7.5" d="M15 15 L49 49 M49 15 L15 49"/>`,
    plus: `<path ${W} stroke-width="7.5" d="M32 11 V53 M11 32 H53"/>`,
    gear: `<path fill="#fff" fill-rule="evenodd" d="${gear(32, 32, 28, 21, 8)} M41 32 A9 9 0 1 0 23 32 A9 9 0 1 0 41 32 Z"/>`,
  },
};

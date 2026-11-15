import 'package:flutter/painting.dart';

import '../theme.dart';
import 'doodle.dart';

// Die Doodles aus dem Prototyp, Strich für Strich übernommen.
// Große Illustrationen: viewBox 230 × 196. Kacheln auf dem Start: 108 × 104.

typedef P = DoodlePart;

const _big = Size(230, 196);
const _tile = Size(108, 104);

// ── Schritt 1 ──────────────────────────────────────────────

DoodleDef washerStart(Color accent) => DoodleDef(_big, [
      P.path('M98 12 L101 21', width: 3, anim: DoodleAnim.bob),
      P.path('M113 7 L113 17', width: 3, anim: DoodleAnim.bob, delay: 0.2),
      P.path('M128 12 L125 21', width: 3, anim: DoodleAnim.bob, delay: 0.4),
      P.path('M56 33 Q56 29 61 29 L163 27 Q169 27 169 33 L171 170 Q171 176 165 176 L60 178 Q54 178 54 172 Z', fill: Pal.day.white),
      P.path('M55 58 L170 56'),
      P.circle(72, 44, 5, fill: Pal.day.doodle),
      P.path('M90 44 L118 43'),
      P.circle(149, 43, 7, fill: accent),
      P.circle(112, 117, 43, fill: Pal.day.doodle),
      P.circle(112, 117, 28, fill: accent, stroke: Pal.day.white, width: 3),
      P.path('M90 121 Q101 112 112 121 T134 121', width: 3),
      P.dot(80, 150, 1.6),
      P.dot(86, 157, 1.3),
      P.dot(141, 86, 1.6),
      P.dot(146, 93, 1.2),
      P.path('M68 178 L68 188 M156 177 L156 187'),
      P.path('M212 92 Q214 52 172 44', anim: DoodleAnim.nudge),
      P.path('M182 35 L171 44 L183 52', anim: DoodleAnim.nudge),
      P.path('M20 120 Q8 132 22 140 Q34 146 26 160 Q20 170 32 176', width: 3),
    ]);

DoodleDef dryerStart(Color accent) => DoodleDef(_big, [
      P.path('M98 24 Q94 19 98 14 Q102 9 98 4', width: 3, anim: DoodleAnim.bob),
      P.path('M113 22 Q109 17 113 12 Q117 7 113 2', width: 3, anim: DoodleAnim.bob, delay: 0.2),
      P.path('M128 24 Q124 19 128 14 Q132 9 128 4', width: 3, anim: DoodleAnim.bob, delay: 0.4),
      P.path('M56 33 Q56 29 61 29 L163 27 Q169 27 169 33 L171 170 Q171 176 165 176 L60 178 Q54 178 54 172 Z', fill: Pal.day.white),
      P.path('M55 58 L170 56'),
      P.rect(68, 38, 34, 11, 3, fill: Pal.day.doodle),
      P.path('M74 43.5 L80 43.5', stroke: Pal.day.white, width: 2),
      P.circle(148, 43, 8, fill: accent),
      P.path('M148 43 L152 38', width: 2.5),
      P.circle(112, 115, 42, fill: Pal.day.doodle),
      P.circle(112, 115, 29, fill: Pal.day.peach, stroke: Pal.day.white, width: 3),
      P.path('M100 108 L107 103 Q112 107 117 103 L124 108 L121 115 L118 113 L118 128 L106 128 L106 113 L103 115 Z',
          fill: Pal.day.white, width: 2.5, anim: DoodleAnim.tumble),
      P.dot(141, 84, 1.6),
      P.dot(80, 148, 1.6),
      P.path('M80 166 L144 165', width: 3),
      P.path('M68 178 L68 188 M156 177 L156 187'),
      P.path('M170 120 Q196 118 198 140 Q200 162 216 166', width: 5),
      P.path('M20 120 Q8 132 22 140 Q34 146 26 160 Q20 170 32 176', width: 3),
    ]);

// ── Schritt 2 ──────────────────────────────────────────────

DoodleDef machineRunning(Color accent) => DoodleDef(_big, [
      P.path('M84 14 L88 23 M100 9 L101 19 M116 13 L113 22', width: 3),
      P.path('M50 37 Q50 32 55 32 L150 30 Q156 30 156 36 L158 170 Q158 176 152 176 L54 178 Q48 178 48 172 Z', fill: Pal.day.white),
      P.path('M49 60 L157 58'),
      P.circle(66, 46, 5, fill: Pal.day.doodle),
      P.path('M84 46 L110 45'),
      P.circle(102, 118, 41, fill: Pal.day.doodle),
      P.path('M102 92 Q124 94 126 116 Q127 136 106 140 Q88 142 84 126 Q82 110 98 108 Q110 108 110 118 Q110 126 102 126',
          stroke: Pal.day.white, width: 3.5, anim: DoodleAnim.spin),
      P.dot(74, 145, 1.6),
      P.dot(131, 88, 1.6),
      P.dot(136, 95, 1.2),
      P.path('M62 178 L62 188 M144 177 L144 187'),
      P.path('M32 80 Q24 88 32 96 Q40 104 32 112', width: 3, anim: DoodleAnim.hum),
      P.path('M20 86 Q14 92 20 98', width: 3, anim: DoodleAnim.hum, delay: 0.3),
      P.circle(186, 52, 26, fill: accent),
      P.path('M186 38 L186 52 L196 58'),
      P.path('M176 22 L182 25 M196 22 L190 25', width: 3),
      P.path('M176 132 Q192 124 196 140 Q200 156 214 150', width: 3),
    ]);

// ── Schritt 3 ──────────────────────────────────────────────

const _bell = Offset(195, 10);

DoodleDef laundryDone(Color accent) => DoodleDef(_big, [
      P.path('M58 82 Q62 52 88 58 Q100 34 128 48 Q150 40 162 66 Q170 74 166 84', fill: Pal.day.white),
      P.path('M96 60 Q104 70 116 62', width: 3),
      P.path('M140 54 Q146 64 140 74', width: 3),
      P.path('M40 96 Q40 86 50 86 L172 84 Q182 84 182 94 L182 100 L40 102 Z', fill: Pal.day.white),
      P.path('M48 104 L174 102 L160 176 Q159 182 152 182 L70 183 Q63 183 62 177 Z', fill: Pal.day.doodle),
      P.path('M57 128 L167 126 M63 154 L162 153', stroke: Pal.day.white, width: 3),
      P.path('M90 108 L94 178 M132 107 L129 178', stroke: Pal.day.white, width: 3),
      P.dot(75, 118, 1.5),
      P.dot(112, 140, 1.5),
      P.dot(148, 166, 1.5),
      P.path('M170 92 Q186 104 180 122 Q176 132 184 138', width: 3),
      P.path('M186 22 Q187 12 195 12 Q203 12 205 22 L208 40 L182 41 Z', fill: Pal.day.white, anim: DoodleAnim.ring, pivot: _bell),
      P.path('M178 42 L212 40', anim: DoodleAnim.ring, pivot: _bell),
      P.circle(195, 47, 3.5, fill: Pal.day.doodle, anim: DoodleAnim.ring, pivot: _bell),
      P.path('M170 12 L176 17 M168 28 L175 28 M218 10 L213 16 M222 26 L215 27', width: 3, anim: DoodleAnim.buzz),
      P.path('M24 60 L30 54 M20 46 L28 46 M26 34 L31 40', width: 3),
    ]);

// ── Kacheln auf dem Startscreen ────────────────────────────

const _tileBody = 'M22 20 Q22 17 25 17 L83 16 Q87 16 87 20 L88 94 Q88 98 84 98 L25 99 Q21 99 21 95 Z';

DoodleDef washerTile({required bool running}) => DoodleDef(_tile, [
      if (!running) ...[
        P.path('M44 6 L46 12', width: 2.4, anim: DoodleAnim.bob),
        P.path('M54 3 L54 10', width: 2.4, anim: DoodleAnim.bob, delay: 0.2),
        P.path('M64 6 L62 12', width: 2.4, anim: DoodleAnim.bob, delay: 0.4),
      ],
      P.path(_tileBody, fill: Pal.day.white, width: 3),
      P.path('M21.5 32 L87.5 31', width: 3),
      P.circle(31, 24.5, 3, fill: Pal.day.doodle, width: 3),
      P.path('M41 24.5 L56 24', width: 3),
      P.circle(54.5, 64, 24, fill: Pal.day.doodle, width: 3),
      if (running) ...[
        P.path('M54.5 47 Q67 48.5 68 61 Q69 74 57 75.5 Q46 76.5 44.5 67.5 Q43.5 59 52 58.5 Q58 58.5 58 64',
            stroke: Pal.day.white, width: 2.6, anim: DoodleAnim.spin),
        P.path('M10 50 Q6 56 10 62 Q14 68 10 74', width: 2.4, anim: DoodleAnim.hum),
      ] else ...[
        P.circle(54.5, 64, 15, fill: Pal.day.pink, stroke: Pal.day.white, width: 2.4),
        P.path('M43 66 Q49 61 54.5 66 T66 66', width: 2.4),
      ],
    ]);

DoodleDef dryerTile({required bool running}) => DoodleDef(_tile, [
      if (!running) ...[
        P.path('M44 13 Q41.5 10 44 7 Q46.5 4 44 1', width: 2.4, anim: DoodleAnim.bob),
        P.path('M54 12 Q51.5 9 54 6 Q56.5 3 54 0', width: 2.4, anim: DoodleAnim.bob, delay: 0.2),
        P.path('M64 13 Q61.5 10 64 7 Q66.5 4 64 1', width: 2.4, anim: DoodleAnim.bob, delay: 0.4),
      ],
      P.path(_tileBody, fill: Pal.day.white, width: 3),
      P.path('M21.5 32 L87.5 31', width: 3),
      P.rect(29, 21, 20, 7, 2, fill: Pal.day.doodle, width: 3),
      P.circle(76, 24.5, 4.5, fill: Pal.day.peach, width: 3),
      P.circle(54.5, 63, 24, fill: Pal.day.doodle, width: 3),
      P.circle(54.5, 63, 15.5, fill: Pal.day.peach, stroke: Pal.day.white, width: 2.4),
      P.path('M48 59 L52 56.5 Q54.5 58.5 57 56.5 L61 59 L59.5 62.5 L58 61.5 L58 70 L51 70 L51 61.5 L49.5 62.5 Z',
          fill: Pal.day.white, width: 1.8, anim: running ? DoodleAnim.tumble : DoodleAnim.none),
      if (running)
        P.path('M98 50 Q102 56 98 62 Q94 68 98 74', width: 2.4, anim: DoodleAnim.hum)
      else
        P.path('M34 91 L75 90.5', width: 2.4),
    ]);

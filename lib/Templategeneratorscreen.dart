import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

const kCyan        = Color(0xFF1BA8D4);
const kCyanDark    = Color(0xFF1890B8);
const kCyanLight   = Color(0xFF26C0F0);
const kBgWhite     = Color(0xFFFFFFFF);
const kBgLight     = Color(0xFFF6FAFE);
const kCardBg      = Color(0xFFF0F7FF);
const kCardBorder  = Color(0xFFD1E9F6);
const kBorderLight = Color(0xFFE8EFF5);
const kTextPrimary = Color(0xFF111827);
const kTextSub     = Color(0xFF6B7280);
const kTextMuted   = Color(0xFF9CA3AF);
const kDarkBg      = Color(0xFF0D1B2A);
const kDarkCard    = Color(0xFF1A2744);
const kDarkBorder  = Color(0xFF1E3354);
const kDarkSub     = Color(0xFF8899AA);

const List<Map<String, dynamic>> kCategories = [
  {
    'label': 'Business',
    'icon': Icons.business_center_rounded,
    'emoji': '💼',
    'types': ['Business Proposal','Project Report','Meeting Agenda','Executive Summary','Invoice'],
  },
  {
    'label': 'Website',
    'icon': Icons.web_rounded,
    'emoji': '🌐',
    'types': ['Flower Shop','Restaurant','Portfolio','Product Landing','E-commerce'],
  },
  {
    'label': 'Email',
    'icon': Icons.email_rounded,
    'emoji': '📧',
    'types': ['Professional Email','Follow-up Email','Apology Email','Cold Outreach','Thank You Email'],
  },
  {
    'label': 'Resume',
    'icon': Icons.person_rounded,
    'emoji': '📄',
    'types': [
      'Professional Resume',
      'Modern Resume',
      'Creative Resume',
      'Cover Letter',
      'Portfolio Bio',
    ],
  },
  {
    'label': 'Social',
    'icon': Icons.share_rounded,
    'emoji': '📱',
    'types': ['Instagram Caption','Twitter/X Post','LinkedIn Post','YouTube Description','Product Launch Post'],
  },
  {
    'label': 'Legal',
    'icon': Icons.gavel_rounded,
    'emoji': '⚖️',
    'types': ['NDA Agreement','Privacy Policy','Terms & Conditions','Freelance Contract','Disclaimer'],
  },
];

// ═══════════════════════════════════════════════════════════════
// PROMPT BUILDERS
// ═══════════════════════════════════════════════════════════════

String _buildPrompt(String category, String type, String idea, String tone, String language) {

  // ── Website ──────────────────────────────────────────────────
  if (category == 'Website') {
    return '''Generate a COMPLETE, BEAUTIFUL single-page HTML website for: "$idea" ($type).
Requirements:
- Use ONLY pure HTML + inline CSS (no external frameworks)
- Include hero section with gradient background, navigation, about section, products/services grid, contact/CTA section, footer
- Use beautiful colors matching the theme
- Use Google Fonts (via @import in style tag)
- Add hover effects, smooth transitions, box shadows
- Mobile-responsive using CSS flexbox/grid
- Include real placeholder content relevant to "$idea"
- Tone: $tone
- Output ONLY complete HTML starting with <!DOCTYPE html>, nothing else''';
  }

  // ════════════════════════════════════════════════════════════
  // PROFESSIONAL RESUME
  // ════════════════════════════════════════════════════════════
  if (category == 'Resume' && type == 'Professional Resume') {
    return '''Create a COMPLETE PROFESSIONAL RESUME HTML page for: "$idea"

CRITICAL OUTPUT RULES — FOLLOW EXACTLY:
- Start output with exactly: <!DOCTYPE html>
- NO ```html, NO backticks, NO markdown, NO explanation before or after
- ALL CSS inside one <style> tag in <head>
- box-sizing: border-box on * selector
- word-wrap: break-word on all elements
- overflow-x: hidden on body
- The HTML must include EVERY section listed below — do NOT skip any section

FONTS: @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap'); apply font-family: 'Inter', sans-serif to body

COLORS:
- Navy: #1a3a5c
- Navy light: #2d6a9f
- Page bg: #ffffff
- Sidebar bg: #f0f4f8
- Border: #c8dff0
- Text dark: #1a3a5c
- Text grey: #374151
- Text muted: #6b7280

PAGE STRUCTURE:
- body: margin 0, padding 20px, background #f5f7fa
- .resume-wrap: max-width 900px, margin 0 auto, background white, box-shadow 0 4px 24px rgba(0,0,0,0.10), border-radius 12px, overflow hidden

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 1 — HEADER (full width)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- background: linear-gradient(135deg, #1a3a5c, #2d6a9f)
- padding: 32px 36px
- Full name: font-size 30px, font-weight 700, color white, margin 0
- Job title: font-size 14px, color #a8d4f0, margin-top 6px
- Contact row: display flex, flex-wrap wrap, gap 20px, margin-top 14px
  Each contact item: color white, font-size 12px, display flex, align-items center, gap 5px
  Items: 📧 email@example.com  📱 +91 99999 99999  📍 Chennai, India  🔗 linkedin.com/in/name

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 2 — TWO COLUMN BODY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
.body-wrap: display flex
.sidebar: width 32%, min-width 32%, background #f0f4f8, padding 28px 20px
.main: width 68%, padding 28px 28px

--- SIDEBAR CONTENTS (in this exact order) ---

.section-heading style (use for ALL sidebar headings):
  font-size 10px, font-weight 700, letter-spacing 2px, text-transform uppercase
  color #1a3a5c, border-bottom 2px solid #1a3a5c, padding-bottom 5px, margin-bottom 14px, margin-top 22px

[A] PHOTO
  - Circle div: width 90px, height 90px, border-radius 50%
  - background: linear-gradient(135deg, #1a3a5c, #2d6a9f)
  - display flex, align-items center, justify-content center
  - color white, font-size 13px, font-weight 600, text "Photo"
  - margin 0 auto 20px auto

[B] OBJECTIVE
  - .section-heading "OBJECTIVE"
  - Box: background #e8f4fd, border-left 4px solid #1a3a5c, border-radius 6px, padding 12px
  - Text: font-size 13px, color #374151, line-height 1.8, font-style italic
  - Write 3 sentences relevant to "$idea"

[C] SKILLS
  - .section-heading "SKILLS"
  - 8 skills, each in a chip card:
    background white, border 1px solid #c8dff0, border-radius 8px
    padding 8px 12px, margin-bottom 8px
    Top row: skill name left (12px bold #1a3a5c) + percent right (12px #1a3a5c)
    display flex, justify-content space-between
    Progress bar div below: height 5px, background #dde8f5, border-radius 3px
    Inner fill div: background linear-gradient(90deg,#1a3a5c,#2d6a9f), border-radius 3px, height 100%
    Each skill different width: 90%, 85%, 80%, 75%, 70%, 88%, 78%, 65%
  - Skills relevant to "$idea"

[D] LANGUAGES
  - .section-heading "LANGUAGES"
  - 3 languages, each row: name left, dots right
  - Dots: 5 spans, filled = background #1a3a5c, empty = background #dde8f5
    Each dot: width 10px, height 10px, border-radius 50%, display inline-block, margin-left 3px

[E] CERTIFICATIONS
  - .section-heading "CERTIFICATIONS"
  - 6 certifications, each:
    margin-bottom 12px, padding-bottom 12px, border-bottom 1px solid #e5edf5
    Cert name: font-size 12px, font-weight 700, color #1a3a5c
    Issuer: font-size 11px, color #6b7280, margin-top 2px
    Year badge: display inline-block, background #e8f4fd, color #1a3a5c
      font-size 10px, border-radius 10px, padding 1px 8px, margin-top 4px
  - 6 realistic certs relevant to "$idea"

--- MAIN AREA CONTENTS (in this exact order) ---

.main-heading style (use for ALL main headings):
  font-size 13px, font-weight 700, color #1a3a5c
  border-left 4px solid #1a3a5c, padding-left 10px
  margin-bottom 14px, margin-top 26px, text-transform uppercase, letter-spacing 1px

[F] PROFESSIONAL SUMMARY
  - .main-heading "PROFESSIONAL SUMMARY"
  - Paragraph: font-size 13px, color #374151, line-height 1.8
  - 4 sentences summarizing the person's profile

[G] WORK EXPERIENCE
  - .main-heading "WORK EXPERIENCE"
  - 2 job entries, each:
    margin-bottom 20px, padding-bottom 20px, border-bottom 1px solid #e5edf5
    Role: font-size 14px, font-weight 700, color #1a3a5c
    Company row: font-size 13px, color #374151 + date badge inline
    Date badge: background #e8f0fe, color #1a3a5c, font-size 11px, border-radius 10px, padding 2px 10px, margin-left 8px
    4 bullet points: ul with list-style none, padding-left 0
      li before content "•", color #1a3a5c, margin-right 6px
      font-size 13px, color #374151, line-height 1.7, margin-bottom 4px

[H] INTERNSHIP
  - .main-heading "INTERNSHIP"
  - 2 internship entries same format as work experience
  - Add "INTERN" badge next to company: background #e0f2fe, color #0369a1, font-size 10px, border-radius 4px, padding 2px 8px, margin-left 6px

[I] EDUCATION
  - .main-heading "EDUCATION"
  - 2 entries, each:
    display flex, justify-content space-between, align-items flex-start
    margin-bottom 16px
    Left: Degree 14px bold #1a3a5c, University 13px #374151 margin-top 3px
    Right: Year badge + CGPA text — font-size 12px, color #6b7280, text-align right

[J] PROJECTS
  - .main-heading "PROJECTS"
  - 2 project cards:
    background #f8fafc, border 1px solid #e5edf5, border-radius 8px
    padding 14px, margin-bottom 12px
    Project name: 13px bold #1a3a5c
    Description: 12px #374151, margin-top 4px, line-height 1.6
    Tech tags row: margin-top 8px, display flex, flex-wrap wrap, gap 5px
    Each tag: background #e8f0fe, color #1a3a5c, font-size 10px, border-radius 10px, padding 2px 9px

[K] ACHIEVEMENTS
  - .main-heading "ACHIEVEMENTS"
  - 4 items, each:
    display flex, align-items flex-start, gap 8px, margin-bottom 8px
    ★ span: color #f59e0b, font-size 14px, flex-shrink 0
    Text: font-size 13px, color #374151, line-height 1.6

MOBILE RESPONSIVE:
@media (max-width: 640px) {
  .body-wrap { flex-direction: column }
  .sidebar, .main { width: 100%; min-width: 100% }
  .resume-wrap { border-radius: 0 }
}

Generate ALL content realistically based on: "$idea"
Tone: $tone | Language: $language
RETURN ONLY THE HTML. NOTHING ELSE.''';
  }

  // ════════════════════════════════════════════════════════════
  // MODERN RESUME
  // ════════════════════════════════════════════════════════════
  if (category == 'Resume' && type == 'Modern Resume') {
    return '''Create a COMPLETE MODERN RESUME HTML page for: "$idea"

CRITICAL OUTPUT RULES:
- Start output with exactly: <!DOCTYPE html>
- NO backticks, NO markdown, NO explanation
- ALL CSS inside <style> tag in <head>
- box-sizing: border-box on *
- overflow-x: hidden on body
- Include EVERY section listed below — do NOT skip any

FONTS: @import url('https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600;700&display=swap'); font-family: 'Poppins', sans-serif on body

COLORS:
- Primary: #0ea5e9
- Dark: #0f172a
- Card bg: #ffffff
- Page bg: #f1f5f9
- Border: #e2e8f0
- Text dark: #0f172a
- Text grey: #374151
- Text muted: #64748b

PAGE STRUCTURE:
- body: margin 0, padding 24px, background #f1f5f9
- .resume: max-width 860px, margin 0 auto, display flex, flex-direction column, gap 16px

CARD STYLE (apply to every section card):
  background white, border-radius 14px
  box-shadow 0 2px 12px rgba(0,0,0,0.06)
  padding 24px 28px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 1 — HERO HEADER CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 100%)
- padding 32px 32px, border-radius 14px
- display flex, justify-content space-between, align-items center, flex-wrap wrap, gap 20px
- LEFT:
  Name: 32px, font-weight 700, color white
  Title: 15px, color #0ea5e9, margin-top 6px
  Tagline: 13px, color #94a3b8, margin-top 4px
- RIGHT: contact pills column (display flex, flex-direction column, gap 8px, align-items flex-end)
  Each pill: background rgba(255,255,255,0.08), border 1px solid rgba(255,255,255,0.15)
  border-radius 20px, padding 5px 14px, color white, font-size 12px
  Items: 📧 email  📱 phone  📍 location  🔗 LinkedIn

SECTION TITLE STYLE (use for ALL sections below):
  font-size 11px, font-weight 700, letter-spacing 3px
  text-transform uppercase, color #0ea5e9
  margin-bottom 16px, padding-bottom 8px
  border-bottom 2px solid #e2e8f0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 2 — CAREER OBJECTIVE CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section title "CAREER OBJECTIVE"
- Inner box: background linear-gradient(135deg,#f0f9ff,#e0f2fe)
  border-radius 10px, padding 18px
  border-left 4px solid #0ea5e9
- Text: 14px italic #0f172a, line-height 1.9
- Keyword pills row (margin-top 12px, flex, gap 8px):
  3 pills: background #0ea5e9, color white, border-radius 20px, 11px, padding 3px 12px
  Relevant keywords e.g. "Problem Solver", "Team Player", "Fast Learner"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 3 — SKILLS CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section title "SKILLS"
- CSS grid: grid-template-columns repeat(3,1fr), gap 14px
- Each skill card:
  border 1px solid #e2e8f0, border-radius 10px, padding 14px
  border-top 3px solid #0ea5e9, text-align center
  Skill name: 12px bold #0f172a, margin-bottom 8px
  Bar container: background #e2e8f0, border-radius 4px, height 6px, overflow hidden
  Bar fill: background #0ea5e9, height 100%, border-radius 4px
  Add style="width:X%" inline on fill div — different % per skill
  Level text: 10px #64748b, margin-top 5px
  e.g. "Expert", "Advanced", "Proficient", "Good", "Familiar"
- 8 skills total

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 4 — WORK EXPERIENCE CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section title "WORK EXPERIENCE"
- Timeline container: position relative, padding-left 24px
  border-left 2px solid #e2e8f0
- Each entry: position relative, margin-bottom 24px
  Timeline dot: position absolute, left -31px, top 4px
    width 12px, height 12px, border-radius 50%, background #0ea5e9, border 2px solid white
    box-shadow 0 0 0 2px #0ea5e9
  Role: 15px bold #0f172a
  Company + date row: display flex, align-items center, gap 8px, margin-top 4px
    Company: 13px #0ea5e9
    Date badge: background #f0f9ff, color #0ea5e9, border 1px solid #bae6fd
      font-size 11px, border-radius 10px, padding 2px 10px
  Bullet list (margin-top 10px): ul list-style none, padding 0
    li: font-size 13px, color #374151, line-height 1.7, margin-bottom 5px
    li::before: content "→", color #0ea5e9, margin-right 8px, font-weight 600
- 2 work experience entries

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 5 — INTERNSHIP CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section title "INTERNSHIP"
- Same timeline style as work experience
- 2 internship entries
- Add "INTERN" badge: background #fef3c7, color #d97706
  font-size 10px, border-radius 4px, padding 2px 8px, margin-left 6px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 6 — EDUCATION CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section title "EDUCATION"
- 2 education cards: border-left 4px solid #0ea5e9
  background #f8fafc, border-radius 8px, padding 16px, margin-bottom 12px
  display flex, justify-content space-between, align-items flex-start
  Left: Degree 14px bold #0f172a, University 13px #374151
  Right: Year badge (background #f0f9ff, color #0ea5e9, border 1px solid #bae6fd, border-radius 10px, padding 2px 10px, 11px)
         CGPA: 12px #64748b, margin-top 4px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 7 — CERTIFICATIONS CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section title "CERTIFICATIONS"
- CSS grid: grid-template-columns repeat(2,1fr), gap 14px
- Each cert card: display flex, align-items center, gap 14px
  border 1px solid #e2e8f0, border-radius 12px, padding 16px
  box-shadow 0 2px 8px rgba(14,165,233,0.07)
- Left circle icon: width 48px, height 48px, border-radius 50%, flex-shrink 0
  background linear-gradient(135deg,#0ea5e9,#6366f1)
  display flex, align-items center, justify-content center
  font-size 20px (emoji icon)
- Right: cert name 13px bold #0f172a, issuer 12px #64748b margin-top 2px
  Bottom row: year badge (background #f0f9ff, color #0ea5e9, border 1px solid #bae6fd, 11px, border-radius 20px)
  + "Verified ✓" (background #f0fdf4, color #16a34a, 11px, border-radius 20px, padding 2px 8px)
- 6 realistic certifications with different emojis (🎓 💻 📜 🏅 ☁️ 🔐)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 8 — PROJECTS CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section title "PROJECTS"
- 2 project cards: border 1px solid #e2e8f0, border-radius 10px, padding 18px, margin-bottom 12px
  transition transform 0.2s, box-shadow 0.2s
  on hover (add :hover in CSS): transform translateY(-2px), box-shadow 0 8px 24px rgba(14,165,233,0.12)
  Project name: 14px bold #0f172a
  Description: 13px #374151, margin-top 6px, line-height 1.6
  Tech tags: margin-top 10px, display flex, flex-wrap wrap, gap 6px
    Each: background #f0f9ff, color #0ea5e9, border 1px solid #bae6fd, 11px, border-radius 10px, padding 2px 10px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 9 — ACHIEVEMENTS CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section title "ACHIEVEMENTS"
- 4 items: display flex, align-items flex-start, gap 10px, margin-bottom 10px
  ✦ span: color #0ea5e9, font-size 16px, flex-shrink 0
  Text: 13px #374151, line-height 1.6

MOBILE: @media(max-width:640px){ grid cols → 1 col, hero flex-direction column, text-align center }

Generate ALL content realistically for: "$idea"
Tone: $tone | Language: $language
RETURN ONLY HTML. NOTHING ELSE.''';
  }

  // ════════════════════════════════════════════════════════════
  // CREATIVE RESUME
  // ════════════════════════════════════════════════════════════
  if (category == 'Resume' && type == 'Creative Resume') {
    return '''Create a COMPLETE CREATIVE RESUME HTML page for: "$idea"

CRITICAL OUTPUT RULES:
- Start output with exactly: <!DOCTYPE html>
- NO backticks, NO markdown, NO explanation
- ALL CSS inside <style> tag
- box-sizing: border-box on *
- overflow-x: hidden on body
- Include EVERY section listed below — do NOT skip any

FONTS: @import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;600;700&family=DM+Sans:wght@300;400;500&display=swap');
  headings: 'Space Grotesk', body: 'DM Sans'

COLORS:
- Page bg: #0d0d0d
- Card bg: #161616
- Card border: #2a2a2a
- Accent teal: #00f5d4
- Accent pink: #f72585
- Text bright: #f1f1f1
- Text mid: #b0b0b0
- Text dim: #888888

PAGE STRUCTURE:
- body: margin 0, padding 24px, background #0d0d0d
- .resume: max-width 860px, margin 0 auto, display flex, flex-direction column, gap 16px

CARD STYLE (apply to every section card):
  background #161616, border 1px solid #2a2a2a
  border-radius 14px, padding 24px 28px

SECTION HEADING STYLE (use for ALL sections):
  font-family 'Space Grotesk', font-size 11px, font-weight 700
  letter-spacing 4px, text-transform uppercase, color #00f5d4
  margin-bottom 6px
  After heading: div height 1px, background linear-gradient(90deg,#00f5d4,transparent), margin-bottom 18px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 1 — HERO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- background: linear-gradient(135deg,#0d0d0d,#1a0a2e)
- padding 56px 40px, border-radius 14px, text-align center
- Name: 54px, font-family 'Space Grotesk', font-weight 700
  gradient text: background linear-gradient(90deg,#00f5d4,#f72585)
  -webkit-background-clip text, -webkit-text-fill-color transparent
- Title: 16px, color #888, letter-spacing 5px, text-transform uppercase, margin-top 10px
- Tagline: 14px, color #b0b0b0, margin-top 8px, font-style italic
- Contact row: display flex, justify-content center, flex-wrap wrap, gap 20px, margin-top 24px
  Each: color #888, font-size 13px, transition color 0.2s
  emoji + text, hover color #00f5d4

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 2 — OBJECTIVE CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section heading "OBJECTIVE"
- Inner box: background rgba(0,245,212,0.04), border 1px solid rgba(0,245,212,0.15)
  border-radius 10px, padding 18px, position relative
  border-left 3px solid #f72585
- Top-right "ABOUT ME" badge: float right or position absolute top 14px right 14px
  background #f72585, color white, font-size 9px, font-weight 700
  letter-spacing 1px, border-radius 4px, padding 3px 8px
- Text: 14px #b0b0b0, line-height 2, font-style italic

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 3 — SKILLS CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section heading "SKILLS"
- Flex wrap, gap 10px
- 8 skill items, each:
  width calc(25% - 10px), background rgba(255,255,255,0.03)
  border 1px solid #2a2a2a, border-radius 12px, padding 14px 10px
  text-align center, transition all 0.2s
  hover: border-color #00f5d4, background rgba(0,245,212,0.05)
  Skill name: 11px bold #f1f1f1, margin-bottom 8px
  Dot row: display flex, justify-content center, gap 4px
    5 dots per skill: each dot width 8px height 8px border-radius 50%
    Filled dots: background #00f5d4
    Empty dots: background #2a2a2a, border 1px solid #3a3a3a
    e.g. skill 1 = 5 filled, skill 2 = 4 filled, etc.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 4 — WORK EXPERIENCE CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section heading "WORK EXPERIENCE"
- 2 entries, each glass card:
  background rgba(255,255,255,0.03), border 1px solid rgba(255,255,255,0.08)
  border-radius 12px, padding 20px, margin-bottom 14px
  backdrop-filter blur(10px)
  Role: 16px bold #f1f1f1, font-family 'Space Grotesk'
  Top row: display flex, justify-content space-between, align-items center
  Company: 13px #00f5d4
  Date badge: background #1a1a1a, border 1px solid #2a2a2a
    color #888, font-size 11px, border-radius 20px, padding 2px 12px
  Bullet list: margin-top 12px, list-style none, padding 0
    li: font-size 13px, color #b0b0b0, line-height 1.8, margin-bottom 5px
    li::before: content "▸", color #00f5d4, margin-right 8px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 5 — INTERNSHIP CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section heading "INTERNSHIP"
- Same glass card style as experience
- 2 internship entries
- "INTERN" badge: border 1px solid #f72585, color #f72585
  font-size 10px, border-radius 4px, padding 2px 8px, margin-left 8px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 6 — EDUCATION CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section heading "EDUCATION"
- 2 education entries, each glass card:
  display flex, justify-content space-between, align-items flex-start
  Degree: 14px bold #f1f1f1, University: 13px #888, margin-top 4px
  Year: badge border 1px solid rgba(0,245,212,0.4), color #00f5d4, 11px, border-radius 20px, padding 2px 10px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 7 — CERTIFICATIONS CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section heading "CERTIFICATIONS"
- CSS grid: grid-template-columns repeat(3,1fr), gap 12px
- Each cert card: glass-morphism style:
  background rgba(255,255,255,0.03), border 1px solid rgba(255,255,255,0.08)
  border-radius 12px, padding 16px, position relative, overflow hidden
  transition all 0.2s
  hover: border-color #00f5d4, transform translateY(-3px)
- Top-right corner glow div: position absolute, top 0, right 0
  width 40px, height 40px
  background linear-gradient(135deg,#00f5d4,#f72585), opacity 0.15
  border-radius 0 12px 0 40px
- Cert emoji: font-size 22px, margin-bottom 8px, display block
- Cert name: font-size 12px, font-weight 700, color #f1f1f1, line-height 1.4
- Issuer: font-size 11px, color #888, margin-top 4px
- Year pill: margin-top 8px, display inline-block
  border 1px solid rgba(0,245,212,0.35), color #00f5d4
  font-size 10px, border-radius 20px, padding 2px 10px
- 6 realistic certifications with emojis: 🎓 💻 📜 🏅 ☁️ 🔐

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 8 — PROJECTS CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section heading "PROJECTS"
- 2 project cards: glass style
  hover: border-color #00f5d4, transform translateY(-4px), box-shadow 0 8px 32px rgba(0,245,212,0.10)
  Project name: 15px bold
    gradient text: background linear-gradient(90deg,#00f5d4,#f72585)
    -webkit-background-clip text, -webkit-text-fill-color transparent
  Description: 13px #b0b0b0, margin-top 6px, line-height 1.7
  Tech tags: margin-top 12px, display flex, flex-wrap wrap, gap 6px
    Each: background #1a1a1a, border 1px solid #2a2a2a
    color #00f5d4, font-size 11px, border-radius 4px, padding 3px 10px

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECTION 9 — ACHIEVEMENTS CARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Section heading "ACHIEVEMENTS"
- 4 items: display flex, align-items flex-start, gap 10px, margin-bottom 10px
  ◆ span: color #f72585, font-size 14px, flex-shrink 0, margin-top 2px
  Text: 13px #b0b0b0, line-height 1.7

MOBILE: @media(max-width:640px){ skill items width calc(50%-10px), cert grid 1 col, hero padding 36px 20px, name font-size 38px }

Generate ALL content realistically for: "$idea"
Tone: $tone | Language: $language
RETURN ONLY HTML. NOTHING ELSE.''';
  }

  // ── Cover Letter ─────────────────────────────────────────────
  if (category == 'Resume' && type == 'Cover Letter') {
    return '''Generate a PROFESSIONAL COVER LETTER in HTML for: "$idea".
DESIGN: Clean letter format. Font: 'Inter' from Google Fonts. Navy header with name + contact. Formal letter body with date, hiring manager address, opening, 2 body paragraphs, closing, signature.
Tone: $tone | Language: $language
ONLY RETURN HTML. NO MARKDOWN.''';
  }

  // ── Portfolio Bio ────────────────────────────────────────────
  if (category == 'Resume' && type == 'Portfolio Bio') {
    return '''Generate a CREATIVE PORTFOLIO BIO PAGE in HTML for: "$idea".
DESIGN: Personal brand page. Font: 'Outfit' from Google Fonts. Gradient hero, about section, skills grid, featured work cards, contact CTA, social links.
Tone: $tone | Language: $language
ONLY RETURN HTML. NO MARKDOWN.''';
  }

  // ── Default ──────────────────────────────────────────────────
  return '''Generate a complete, ready-to-use "$type" template for: "$idea".
Tone: $tone. Language: $language.
Use clear headings (##), bullet points (-), bold (**text**), and proper sections.
Fill in realistic placeholder content. Make it immediately usable.''';
}

bool _isWebTemplate(String category) =>
    category == 'Website' || category == 'Resume';

// ═══════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════

class TemplateGeneratorScreen extends StatefulWidget {
  const TemplateGeneratorScreen({super.key});
  @override
  State<TemplateGeneratorScreen> createState() =>
      _TemplateGeneratorScreenState();
}

class _TemplateGeneratorScreenState extends State<TemplateGeneratorScreen>
    with TickerProviderStateMixin {

  bool    _showHtmlCode          = false;
  int     _selectedCategoryIndex = 0;
  String? _selectedType;
  final   _ideaController        = TextEditingController();
  final   _toneController        = TextEditingController();
  String  _generatedContent      = '';
  bool    _isGenerating          = false;
  bool    _showPreview           = false;
  String  _selectedLanguage      = 'English';
  bool    _isWebPreview          = false;

  WebSocketChannel?  _channel;
  WebViewController? _webController;

  late AnimationController _slideController;
  late Animation<Offset>   _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() =>
    _selectedLanguage = prefs.getString('selected_language') ?? 'English');
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _slideController.dispose();
    _ideaController.dispose();
    _toneController.dispose();
    super.dispose();
  }

  // ── Generate ───────────────────────────────────────────────────

  void _generateTemplate() {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      _showSnack('Please enter your idea or topic!');
      return;
    }

    final cat  = kCategories[_selectedCategoryIndex]['label'] as String;
    final type = _selectedType ??
        (kCategories[_selectedCategoryIndex]['types'] as List<String>)[0];
    final tone = _toneController.text.trim().isNotEmpty
        ? _toneController.text.trim()
        : 'professional';
    final prompt = _buildPrompt(cat, type, idea, tone, _selectedLanguage);

    setState(() {
      _isGenerating     = true;
      _generatedContent = '';
      _showPreview      = false;
      _showHtmlCode     = false;
      _isWebPreview     = _isWebTemplate(cat);
    });

    try { _channel?.sink.close(status.goingAway); } catch (_) {}
    _channel = WebSocketChannel.connect(
        Uri.parse('wss://silo-churn-worst.ngrok-free.dev/ws/chat/'));

    _channel!.stream.listen((data) {
      final decoded = jsonDecode(data);
      final msgType = decoded['type'];
      final text    = decoded['message'] ?? '';
      setState(() {
        if (msgType == 'stream') _generatedContent = text;
        if (msgType == 'done') {
          _isGenerating = false;
          _showPreview  = true;
          _slideController.forward(from: 0);
          if (_isWebPreview) _loadWebPreview();
        }
      });
    }, onError: (_) {
      setState(() => _isGenerating = false);
      _showSnack('Connection error. Check server.');
    });

    _channel!.sink.add(jsonEncode({
      'message':  prompt,
      'language': _selectedLanguage,
      'model':    'Smart',
    }));
  }

  void _loadWebPreview() {
    String html = _cleanHtml();
    if (html.contains('<head>')) {
      html = html.replaceFirst('<head>', '''<head>
<style>
  html, body {
    overflow-y: auto !important;
    height: auto !important;
    min-height: 100% !important;
  }
</style>''');
    }
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..loadHtmlString(html.trim());
  }

  String _cleanHtml() {
    return _generatedContent
        .replaceAll('```html', '')
        .replaceAll('```', '')
        .trim();
  }

  // ── Share Resume — .html file ──────────────────────────────────
  Future<void> _shareResume() async {
    try {
      final html = _cleanHtml();
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/resume.html');
      await file.writeAsString(html, encoding: utf8);
      await Share.shareXFiles(
          [XFile(file.path)],
          text: 'My Resume — Made with Omega AI ✨');
    } catch (e) { _showSnack('Share failed: $e'); }
  }

  // ── Share HTML Code — raw plain text ──────────────────────────
  Future<void> _shareHtmlCode() async {
    try {
      await Share.share(_cleanHtml(), subject: 'HTML Code — Omega AI');
    } catch (e) { _showSnack('Share failed: $e'); }
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: _cleanHtml()));
    _showSnack('Copied! ✅');
  }

  void _shareContent() async {
    if (_generatedContent.isEmpty) return;
    _showHtmlCode ? await _shareHtmlCode() : await _shareResume();
  }

  void _resetAll() {
    setState(() {
      _generatedContent = '';
      _showPreview      = false;
      _selectedType     = null;
      _isWebPreview     = false;
      _showHtmlCode     = false;
    });
    _ideaController.clear();
    _toneController.clear();
    _slideController.reset();
    _webController = null;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: kCyan,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? kDarkBg    : kBgLight;
    final cardColor   = isDark ? kDarkCard  : kBgWhite;
    final textColor   = isDark ? Colors.white : kTextPrimary;
    final subColor    = isDark ? kDarkSub   : kTextSub;
    final borderColor = isDark ? kDarkBorder : kBorderLight;
    final category    = kCategories[_selectedCategoryIndex];
    final catLabel    = category['label'] as String;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: Column(children: [

        // ── Header ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? kDarkBg : kBgWhite,
            border: Border(bottom:
            BorderSide(color: borderColor, width: 0.8)),
          ),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const Icon(Icons.auto_awesome_rounded,
                color: kCyan, size: 20),
            const SizedBox(width: 8),
            const Text('Omega ', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
            const Text('Templates', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
            const Spacer(),
            if (_showPreview)
              TextButton.icon(
                onPressed: _resetAll,
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: kCyan),
                label: const Text('Reset',
                    style: TextStyle(color: kCyan,
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),

        // ── Body ─────────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _sectionLabel('Category', textColor),
                const SizedBox(height: 10),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kCategories.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final cat   = kCategories[i];
                      final isSel = i == _selectedCategoryIndex;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategoryIndex = i;
                          _selectedType = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 72,
                          decoration: BoxDecoration(
                            gradient: isSel
                                ? const LinearGradient(
                                colors: [kCyanDark, kCyanLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                                : null,
                            color: isSel ? null : cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isSel
                                    ? Colors.transparent
                                    : kCardBorder),
                            boxShadow: isSel
                                ? [BoxShadow(
                                color: kCyan.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3))]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(cat['emoji'] as String,
                                  style:
                                  const TextStyle(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text(cat['label'] as String,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isSel
                                          ? Colors.white
                                          : kCyan)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                _sectionLabel('Template Type', textColor),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: (category['types'] as List<String>)
                      .map((type) {
                    final isSel = type ==
                        (_selectedType ??
                            (category['types'] as List<String>)[0]);
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSel
                              ? const LinearGradient(
                              colors: [kCyanDark, kCyanLight],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight)
                              : null,
                          color: isSel ? null : cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSel
                                  ? Colors.transparent
                                  : kCardBorder),
                          boxShadow: isSel
                              ? [BoxShadow(
                              color: kCyan.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Text(type,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSel
                                    ? Colors.white
                                    : kCyan)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                _sectionLabel('Your Details / Topic', textColor),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kCardBorder),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(
                            isDark ? 0.15 : 0.04),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _ideaController,
                    maxLines: 3,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: catLabel == 'Resume'
                          ? 'e.g. John Doe — Flutter Developer, 3 yrs exp, IIT Chennai, worked at TCS & Zoho...'
                          : 'e.g. Bloom Garden — flower shop in Chennai...',
                      hintStyle:
                      TextStyle(color: subColor, fontSize: 13),
                      contentPadding: const EdgeInsets.all(14),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kCardBorder),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(
                            isDark ? 0.15 : 0.04),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _toneController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                      'Tone: professional, elegant, playful...',
                      hintStyle:
                      TextStyle(color: subColor, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.tune_rounded,
                          color: kCyan, size: 20),
                    ),
                  ),
                ),

                if (_isWebTemplate(catLabel))
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kCyan.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kCardBorder),
                    ),
                    child: Row(children: [
                      Icon(
                        catLabel == 'Resume'
                            ? Icons.person_rounded
                            : Icons.web_rounded,
                        color: kCyan, size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        catLabel == 'Resume'
                            ? 'Generates beautiful HTML resume — preview + share!'
                            : 'Generates full HTML website — preview + download!',
                        style: const TextStyle(
                            color: kCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      )),
                    ]),
                  ),

                const SizedBox(height: 20),

                // ── Generate Button ────────────────────────────
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed:
                    _isGenerating ? null : _generateTemplate,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor:
                      kCyan.withOpacity(0.5),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _isGenerating
                            ? null
                            : const LinearGradient(
                            colors: [kCyanDark, kCyanLight],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isGenerating
                            ? const Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Generating...', style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                          ],
                        )
                            : const Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Generate Template',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (_isGenerating &&
                    _generatedContent.isNotEmpty &&
                    !_isWebPreview)
                  _buildTextPreview(cardColor, textColor,
                      isStreaming: true),

                if (_isGenerating && _isWebPreview)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kCardBorder),
                    ),
                    child: Column(children: [
                      const CircularProgressIndicator(color: kCyan),
                      const SizedBox(height: 12),
                      Text(
                        catLabel == 'Resume'
                            ? '📄 Building your resume...'
                            : '🌐 Building your website...',
                        style: const TextStyle(
                            color: kCyan,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        catLabel == 'Resume'
                            ? 'Designing layout, sections & styling...'
                            : 'Writing HTML, CSS, sections...',
                        style: TextStyle(
                            color: subColor, fontSize: 12),
                      ),
                    ]),
                  ),

                if (_showPreview && !_isGenerating)
                  SlideTransition(
                    position: _slideAnimation,
                    child: _isWebPreview
                        ? _buildWebPreview(cardColor, catLabel)
                        : _buildTextPreview(cardColor, textColor,
                        isStreaming: false),
                  ),

                const SizedBox(height: 20),
              ]),
        )),
      ])),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEB / RESUME PREVIEW WIDGET
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWebPreview(Color card, String catLabel) {
    final previewTabLabel =
    catLabel == 'Resume' ? 'Resume' : 'Website';

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [

        // ── Tab switcher ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _showHtmlCode = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_showHtmlCode ? kCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kCardBorder),
                ),
                child: Center(child: Text(previewTabLabel,
                    style: TextStyle(
                        color: !_showHtmlCode
                            ? Colors.white : kCyan,
                        fontWeight: FontWeight.w600))),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _showHtmlCode = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _showHtmlCode ? kCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kCardBorder),
                ),
                child: Center(child: Text('HTML Code',
                    style: TextStyle(
                        color: _showHtmlCode
                            ? Colors.white : kCyan,
                        fontWeight: FontWeight.w600))),
              ),
            )),
          ]),
        ),

        // ── Content ───────────────────────────────────────────
        // ✅ SCROLL FIX: HTML tab = no inner scroll (SelectableText grows naturally)
        // WebView tab = fixed SizedBox height only
        _showHtmlCode
            ? Padding(
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            _cleanHtml(),
            style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                fontFamily: 'monospace',
                color: kTextPrimary),
          ),
        )
            : SizedBox(
          height: 900,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
            child: _webController != null
                ? WebViewWidget(controller: _webController!)
                : const Center(
                child: CircularProgressIndicator(
                    color: kCyan)),
          ),
        ),

        // ── Action buttons ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: _showHtmlCode
              ? Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _copyContent,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy HTML'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kCyan,
                side: const BorderSide(color: kCardBorder),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                const EdgeInsets.symmetric(vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: _shareHtmlCode,
              icon: const Icon(Icons.code_rounded, size: 16),
              label: const Text('Share HTML'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kCyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
            )),
          ])
              : Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _shareResume,
              icon: const Icon(Icons.share_rounded, size: 16),
              label: Text('Share $previewTabLabel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kCyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TEXT PREVIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTextPreview(Color card, Color textColor,
      {required bool isStreaming}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: kCyan.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
              ),
              child: Row(children: [
                Icon(
                  isStreaming
                      ? Icons.pending_rounded
                      : Icons.check_circle_rounded,
                  color: kCyan, size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isStreaming ? 'Generating...' : 'Template Ready! ✨',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kCyan, fontSize: 13),
                ),
                const Spacer(),
                if (!isStreaming) ...[
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: kCyan, size: 18),
                    onPressed: _copyContent,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded,
                        color: kCyan, size: 18),
                    onPressed: _shareContent,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _generatedContent,
                style: TextStyle(
                    color: textColor, fontSize: 13.5, height: 1.7),
              ),
            ),
            if (!isStreaming)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _copyContent,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kCyan,
                      side: const BorderSide(color: kCardBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _shareContent,
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  )),
                ]),
              ),
          ]),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(children: [
      Container(
        width: 3, height: 15,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [kCyanDark, kCyanLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(text,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color, fontSize: 13,
              letterSpacing: 0.2)),
    ]);
  }
}
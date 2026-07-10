#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
╔══════════════════════════════════════════════════════════╗
║  OpenRBE v4 — build.py          ITIE Sénégal            ║
║  Génère index.html depuis RBE-2021-A-2025.xlsx           ║
║  Utilisation : python build.py                           ║
╚══════════════════════════════════════════════════════════╝
"""
import sys, os, json, base64, warnings
from datetime import datetime
warnings.filterwarnings('ignore')

try:
    import pandas as pd
    import openpyxl
except ImportError as e:
    print(f"\n❌  Dépendance manquante : {e}")
    print("   Installez : pip install pandas openpyxl")
    sys.exit(1)

BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
EXCEL_PATH = os.path.join(BASE_DIR, 'data', 'RBE-2021-A-2025.xlsx')
LOGO_PATH  = os.path.join(BASE_DIR, 'img',  'logo_itie.png')
OUT_PATH   = os.path.join(BASE_DIR, 'index.html')

# ── Nettoyage données ─────────────────────────────────────
def clean(v):
    s = str(v).strip() if v is not None and str(v).strip() != '' else ''
    return None if s in ('nan','NA','None','NaN','') else s

def is_ppe(v):
    return str(v).strip() not in ('0','NA','nan','FALSE','false','','None','NaN') if v is not None else False

def load_data(path):
    print(f"📂  Lecture de {os.path.basename(path)} ...")
    df = pd.read_excel(path, sheet_name='Feuil1', skiprows=1, header=0)
    df.columns = ['region','denomination_sociale','prenom_nom','date_acquisition',
                  'pct_action_direct','pct_voix_direct','nationalite','pays_residence',
                  'est_ppe','fonction_ppe','nom_ppe','greffe','regions']
    df = df[df['denomination_sociale'].notna()].copy()
    for col in ['region','denomination_sociale','prenom_nom','nationalite','pays_residence','greffe','fonction_ppe','nom_ppe']:
        df[col] = df[col].apply(clean)
    for col in ['nationalite','pays_residence']:
        df[col] = df[col].str.upper() if df[col].notna().any() else df[col]
    df['region'] = df['region'].str.title() if df['region'].notna().any() else df['region']
    for col in ['nationalite','pays_residence']:
        df[col] = df[col].replace({'SENEGAL':'SÉNÉGAL','EGYPT':'ÉGYPTE'})
    df['pp'] = df['est_ppe'].apply(is_ppe)
    df.loc[df['fonction_ppe'].isin(['0','1']),'fonction_ppe'] = None
    df['pa'] = pd.to_numeric(df['pct_action_direct'], errors='coerce')
    df['pv'] = pd.to_numeric(df['pct_voix_direct'],   errors='coerce')
    df.loc[df['pa']>100,'pa'] = None; df.loc[df['pa']<0,'pa'] = None
    df.loc[df['pv']>100,'pv'] = None; df.loc[df['pv']<0,'pv'] = None
    df['date_acq'] = pd.to_datetime(df['date_acquisition'], errors='coerce')
    df['annee']    = df['date_acq'].dt.year.where(df['date_acq'].notna(), None)
    records = []
    for i, r in enumerate(df.itertuples(index=False), 1):
        records.append({
            'id':i, 'rs':r.region, 'ds':r.denomination_sociale, 'pn':r.prenom_nom,
            'da':r.date_acq.strftime('%d/%m/%Y') if pd.notna(r.date_acq) else None,
            'an':int(r.annee) if pd.notna(r.annee) else None,
            'pa':round(float(r.pa),2) if pd.notna(r.pa) else None,
            'pv':round(float(r.pv),2) if pd.notna(r.pv) else None,
            'na':r.nationalite, 'pr':r.pays_residence, 'pp':bool(r.pp),
            'fp':r.fonction_ppe, 'np':r.nom_ppe, 'gr':r.greffe,
        })
    n_ppe  = sum(1 for r in records if r['pp'])
    n_comp = len(set(r['ds'] for r in records if r['ds']))
    print(f"   ✅  {len(records)} bénéficiaires | {n_comp} entreprises | {n_ppe} PPE")
    return records

def encode_logo(path):
    if not os.path.exists(path): return ''
    with open(path,'rb') as f: return base64.b64encode(f.read()).decode()

# ══════════════════════════════════════════════════════════
def build_html(records, logo_b64, excel_filename):
    data_json  = json.dumps(records, ensure_ascii=False, separators=(',',':'))
    build_time = datetime.now().strftime('%d/%m/%Y à %H:%M')
    n_total    = len(records)

    CSS = """
:root{
  --g:#1565C0;--gd:#0D47A1;--gl:#E3F2FD;
  --y:#F4C300;--yd:#B89300;--yl:#FFF8E1;
  --r:#D62D20;--rl:#FDE8E6;
  --b:#005A8E;--bd:#003D61;
  --bk:#1A1A1A;--bg:#EEF2F7;--wh:#FFFFFF;
  --gray:#6C757D;--brd:#DDE3EA;
  --sh-s:0 2px 8px rgba(0,0,0,.07);
  --sh-m:0 4px 20px rgba(0,0,0,.10);
  --sh-l:0 8px 40px rgba(0,0,0,.16);
  --font:"DM Sans",system-ui,sans-serif;
  --radius:8px;
}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
html{scroll-behavior:smooth}
body{font-family:var(--font);background:var(--bg);color:var(--bk);font-size:14px;line-height:1.6}
::-webkit-scrollbar{width:5px;height:5px}
::-webkit-scrollbar-thumb{background:var(--g);border-radius:3px}

/* ── HEADER ── */
#hdr{background:linear-gradient(135deg,var(--g) 0%,var(--gd) 100%);box-shadow:var(--sh-m);position:sticky;top:0;z-index:1000}
.hi{display:flex;align-items:center;gap:16px;padding:12px 24px;max-width:1900px;margin:0 auto}
.hi img{height:52px;filter:drop-shadow(0 2px 4px rgba(0,0,0,.25));transition:.3s}
.hi img:hover{transform:scale(1.04)}
.hi-sep{width:2px;height:48px;background:rgba(255,255,255,.28);border-radius:1px;flex-shrink:0}
.hi-t{flex:1}
.brand{font-size:1.7rem;font-weight:700;letter-spacing:-.5px;color:#fff;line-height:1.1}
.brand span{color:var(--y)}
.sub{font-size:.79rem;color:rgba(255,255,255,.78);font-style:italic;margin-top:2px}
.tag{font-size:.7rem;color:rgba(255,255,255,.48);margin-top:1px}
.hdr-right{display:flex;align-items:center;gap:10px;flex-shrink:0}
.badge{background:var(--y);color:var(--bk);padding:4px 14px;border-radius:20px;font-size:.71rem;font-weight:700}


/* ── NAV ── */
.nav-bar{background:rgba(0,0,0,.18);border-top:1px solid rgba(255,255,255,.12)}
.nav-bar ul{display:flex;list-style:none;padding:0 24px;max-width:1900px;margin:0 auto;overflow-x:auto}
.nav-bar li a{display:flex;align-items:center;gap:7px;color:rgba(255,255,255,.78);font-size:.83rem;font-weight:500;padding:10px 15px;text-decoration:none;border-bottom:3px solid transparent;transition:.2s;white-space:nowrap}
.nav-bar li a:hover{color:#fff;background:rgba(255,255,255,.08)}
.nav-bar li a.active{color:#fff;border-bottom-color:var(--y);font-weight:700}

/* ── LAYOUT ── */
#app{display:flex;min-height:calc(100vh - 108px);max-width:1900px;margin:0 auto}

/* ── SIDEBAR ── */
#sb{width:235px;flex-shrink:0;background:var(--wh);border-right:1px solid var(--brd);padding:14px 13px;position:sticky;top:108px;height:calc(100vh - 108px);overflow-y:auto}
.sb-ttl{font-size:.77rem;font-weight:700;color:var(--g);text-transform:uppercase;letter-spacing:.8px;margin-bottom:10px;padding-bottom:7px;border-bottom:2px solid var(--gl);display:flex;align-items:center;gap:6px}
.btn-rst{width:100%;margin-bottom:12px;padding:7px;background:var(--rl);color:var(--r);border:1px solid var(--r);border-radius:4px;font-family:var(--font);font-size:.79rem;font-weight:600;cursor:pointer;transition:.2s;display:flex;align-items:center;justify-content:center;gap:5px}
.btn-rst:hover{background:var(--r);color:#fff}
.fb{margin-bottom:10px}
.fl{font-size:.71rem;font-weight:600;color:var(--gray);text-transform:uppercase;letter-spacing:.5px;margin-bottom:3px;display:block}
select{width:100%;padding:5px 7px;border:1px solid var(--brd);border-radius:4px;font-family:var(--font);font-size:.81rem;background:var(--wh);color:var(--bk);cursor:pointer;transition:.15s}
select:focus{outline:none;border-color:var(--g);box-shadow:0 0 0 2px rgba(0,140,69,.15)}
select[multiple]{height:70px}
.rr{display:flex;justify-content:space-between;font-size:.69rem;color:var(--gray);margin-top:2px}
input[type=range]{width:100%;accent-color:var(--g)}
.sw-row{display:flex;align-items:center;justify-content:space-between;font-size:.81rem}
.tog{position:relative;display:inline-block;width:36px;height:20px}
.tog input{opacity:0;width:0;height:0}
.ts{position:absolute;inset:0;background:#ccc;border-radius:20px;transition:.3s;cursor:pointer}
.ts:before{content:"";position:absolute;height:14px;width:14px;left:3px;bottom:3px;background:#fff;border-radius:50%;transition:.3s}
.tog input:checked+.ts{background:var(--r)}
.tog input:checked+.ts:before{transform:translateX(16px)}
.sc{text-align:center;margin-top:12px;padding-top:11px;border-top:1px solid var(--brd)}
.sc-v{font-size:1.75rem;font-weight:700;color:var(--g);line-height:1}
.sc-l{font-size:.67rem;color:var(--gray);text-transform:uppercase;letter-spacing:.4px;margin-top:2px}
.sc-p{font-size:.67rem;color:#aaa;margin-top:2px}
.src-info{margin-top:10px;padding-top:9px;border-top:1px solid var(--brd);font-size:.66rem;color:var(--gray);line-height:1.5;text-align:center}
.src-info strong{color:var(--gd)}

/* ── CONTENT ── */
#ct{flex:1;padding:18px;min-width:0;overflow:hidden}
.page{display:none;animation:fu .3s ease}
.page.active{display:block}
@keyframes fu{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}

/* ── KPI ── */
.kr{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-bottom:16px}
.kpi{background:var(--wh);border-radius:var(--radius);box-shadow:var(--sh-s);padding:13px 12px;display:flex;align-items:center;gap:10px;border-top:4px solid var(--g);transition:.22s;cursor:default}
.kpi:hover{transform:translateY(-2px);box-shadow:var(--sh-m)}
.ki{font-size:1.4rem;width:32px;text-align:center;flex-shrink:0}
.kv{font-size:1.6rem;font-weight:700;line-height:1;letter-spacing:-.4px}
.kl{font-size:.67rem;color:var(--gray);text-transform:uppercase;letter-spacing:.4px;margin-top:2px}

/* ── CARDS ── */
.card{background:var(--wh);border-radius:var(--radius);box-shadow:var(--sh-s);padding:15px;margin-bottom:15px;transition:.22s}
.card:hover{box-shadow:var(--sh-m)}
.ct{font-size:.89rem;font-weight:700;margin-bottom:11px;padding-bottom:8px;border-bottom:2px solid var(--gl);display:flex;align-items:center;gap:7px;flex-wrap:wrap}
.ct i{color:var(--g)}
.g2{display:grid;grid-template-columns:1fr 1fr;gap:15px;margin-bottom:15px}
@media(max-width:860px){.g2{grid-template-columns:1fr}}
.cw{position:relative;height:285px}.cw canvas{max-height:285px}
.cwsm{position:relative;height:210px}.cwsm canvas{max-height:210px}

/* ── TABLES ── */
.tw{overflow-x:auto;margin-top:6px}
table{width:100%;border-collapse:collapse;font-size:.81rem}
thead th{background:var(--bg);font-weight:700;font-size:.72rem;text-transform:uppercase;letter-spacing:.4px;padding:8px 10px;border-bottom:2px solid var(--g);white-space:nowrap;position:sticky;top:0;z-index:1}
tbody tr{border-bottom:1px solid var(--brd);transition:.12s}
tbody tr:hover{background:var(--gl)}
tbody td{padding:6px 10px;vertical-align:middle}
.nr{color:#bbb;font-style:italic;font-size:.83em}
.br{background:var(--r);color:#fff;padding:2px 7px;border-radius:10px;font-size:.7rem;font-weight:700;white-space:nowrap}
.bg{background:var(--g);color:#fff;padding:2px 9px;border-radius:12px;font-size:.7rem;font-weight:600;white-space:nowrap}
.bgr{background:var(--bg);color:var(--gray);padding:2px 9px;border-radius:12px;font-size:.7rem;border:1px solid var(--brd)}

/* ── BUTTONS ── */
.eb{display:flex;gap:7px;margin-bottom:9px;flex-wrap:wrap;align-items:center}
.be{padding:6px 13px;border:none;border-radius:4px;font-family:var(--font);font-size:.76rem;font-weight:600;cursor:pointer;transition:.2s;display:flex;align-items:center;gap:5px}
.bxl{background:#1565C0;color:#fff}.bxl:hover{background:#0D47A1;transform:translateY(-1px)}
.bcsv{background:var(--b);color:#fff}.bcsv:hover{background:var(--bd);transform:translateY(-1px)}
.bsec{background:var(--gl);color:var(--g);border:1px solid var(--g)}.bsec:hover{background:var(--g);color:#fff}

/* ── DATABASE ── */
.db-toolbar{display:flex;align-items:center;gap:10px;margin-bottom:9px;flex-wrap:wrap}
#db-search{flex:1;min-width:220px;padding:8px 12px;border:1px solid var(--brd);border-radius:4px;font-family:var(--font);font-size:.83rem;transition:.2s}
#db-search:focus{outline:none;border-color:var(--g);box-shadow:0 0 0 2px rgba(0,140,69,.15)}
.db-scroll{max-height:540px;overflow-y:auto;border:1px solid var(--brd);border-radius:4px}
.pg-bar{display:flex;align-items:center;gap:7px;margin-top:10px;flex-wrap:wrap;font-size:.79rem;color:var(--gray)}
.pg-btn{padding:4px 9px;border:1px solid var(--brd);border-radius:4px;background:var(--wh);cursor:pointer;font-size:.77rem;font-family:var(--font);transition:.2s}
.pg-btn:hover:not(:disabled){background:var(--gl);border-color:var(--g)}
.pg-btn:disabled{opacity:.35;cursor:default}
.pg-btn.on{background:var(--g);color:#fff;border-color:var(--g)}
.pg-info{margin-left:auto;font-size:.75rem}
.pg-sz{padding:3px 6px;border:1px solid var(--brd);border-radius:4px;font-family:var(--font);font-size:.75rem}
.db-info{font-size:.75rem;color:var(--gray);margin-bottom:6px;min-height:18px}

/* ── SEARCH TABS ── */
.search-tabs{display:flex;gap:0;margin-bottom:16px;border-radius:8px;overflow:hidden;box-shadow:var(--sh-s)}
.search-tab{flex:1;padding:12px 16px;background:var(--wh);border:none;font-family:var(--font);font-size:.88rem;font-weight:600;cursor:pointer;transition:.22s;color:var(--gray);display:flex;align-items:center;justify-content:center;gap:8px;border-bottom:3px solid transparent}
.search-tab:hover{background:var(--bg);color:var(--bk)}
.search-tab.active{background:var(--wh);color:var(--g);border-bottom-color:var(--g)}
.search-tab:first-child{border-right:1px solid var(--brd)}

/* ── SEARCH ── */
.shero{background:linear-gradient(135deg,var(--g),var(--gd));border-radius:var(--radius);padding:24px 20px;margin-bottom:15px}
.shero h3{color:#fff;font-size:1.1rem;font-weight:700;margin-bottom:5px}
.shero p{color:rgba(255,255,255,.75);font-size:.83rem;margin-bottom:12px}
.sw{position:relative}
#si{width:100%;padding:10px 14px;border:none;border-radius:4px;font-family:var(--font);font-size:.9rem;box-shadow:var(--sh-m);transition:.2s}
#si:focus{outline:2px solid var(--y)}
#sdd{position:absolute;top:100%;left:0;right:0;z-index:500;background:#fff;border-radius:0 0 4px 4px;box-shadow:var(--sh-l);max-height:250px;overflow-y:auto;display:none}
.ddi{padding:8px 12px;cursor:pointer;font-size:.86rem;border-bottom:1px solid var(--brd);transition:.12s;display:flex;align-items:center;gap:8px}
.ddi:hover{background:var(--gl);color:var(--gd)}
.ddi mark{background:var(--yl);color:var(--bk);border-radius:2px;padding:0 2px}
.ddi-meta{font-size:.74rem;color:var(--gray);margin-left:auto}

/* ── COMPANY CARD ── */
.cc{background:var(--wh);border-radius:var(--radius);border:1px solid var(--gl);box-shadow:var(--sh-s);margin-bottom:15px;overflow:hidden;animation:fu .3s ease}
.cch{background:var(--gl);padding:14px 18px;display:flex;align-items:center;gap:12px;border-bottom:1px solid rgba(0,140,69,.15)}
.cci{width:42px;height:42px;background:var(--g);border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:1.1rem;color:#fff;flex-shrink:0}
.ccn{font-size:1rem;font-weight:700;color:var(--gd);margin-bottom:3px}
.ccs{display:flex;gap:22px;padding:11px 18px;flex-wrap:wrap}
.csv2{font-size:1.5rem;font-weight:700;color:var(--g);line-height:1;display:block}
.csv2.red{color:var(--r)}
.csl{font-size:.67rem;color:var(--gray);text-transform:uppercase;letter-spacing:.4px;display:block;margin-top:1px}
.ccd{display:grid;grid-template-columns:1fr 1fr;gap:8px 20px;padding:10px 18px 14px;font-size:.81rem;border-top:1px solid var(--brd)}
.cdl{font-weight:600;color:var(--gray);display:flex;align-items:center;gap:4px;margin-bottom:1px}
.cdl i{color:var(--g)}

/* ── MAP ── */
#map{height:480px;border-radius:var(--radius);margin-bottom:10px;z-index:1}

/* ── NETWORK ── */
.nc{display:flex;gap:9px;align-items:flex-end;flex-wrap:wrap;margin-bottom:9px}
.nsg{flex:1;min-width:170px}
.nsg label{display:block;font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.5px;margin-bottom:3px}
.nsg label.gl{color:var(--g)}.nsg label.yl{color:var(--yd)}
.nsg select{width:100%;padding:6px 8px;border:1px solid var(--brd);border-radius:4px;font-size:.83rem;font-family:var(--font)}
.nsg select.gs{border-color:var(--g)}.nsg select.ys{border-color:var(--yd)}
.nb{padding:7px 12px;border:none;border-radius:4px;font-family:var(--font);font-size:.8rem;font-weight:600;cursor:pointer;transition:.2s;display:flex;align-items:center;gap:5px;align-self:flex-end;color:#fff}
.nb.gn{background:var(--g)}.nb.gn:hover{background:var(--gd)}
.nleg{display:flex;gap:13px;font-size:.78rem;color:var(--gray);margin-bottom:7px;align-items:center}
.ld{width:11px;height:11px;border-radius:50%;display:inline-block}
.lg{background:var(--g)}.ly{background:var(--y)}
#nwrap{border:1px solid var(--brd);border-radius:var(--radius);background:#FAFCFB;height:500px;overflow:hidden}
#nsvg{width:100%;height:100%}
.nib{background:#fff;border:1px solid var(--brd);border-radius:var(--radius);padding:10px 14px;margin-bottom:10px;display:flex;align-items:center;gap:10px;box-shadow:var(--sh-s);animation:fu .25s ease}
.niico{width:34px;height:34px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:13px;color:#fff;flex-shrink:0}
.ntip{font-size:.74rem;color:var(--gray);margin-top:7px}
.ntip i{color:var(--g)}
.pkr{display:grid;grid-template-columns:repeat(auto-fit,minmax(132px,1fr));gap:10px;margin-bottom:14px}

/* ══ MODAUX GÉNÉRIQUES ══ */
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:3000;display:flex;align-items:center;justify-content:center;animation:mfade .2s ease;backdrop-filter:blur(3px)}
.modal-overlay.hidden{display:none}
@keyframes mfade{from{opacity:0}to{opacity:1}}
.modal-box{background:var(--wh);border-radius:12px;box-shadow:var(--sh-l);width:100%;max-height:90vh;overflow-y:auto;animation:mslide .25s ease}
@keyframes mslide{from{transform:translateY(-20px);opacity:0}to{transform:translateY(0);opacity:1}}
.modal-hdr{display:flex;align-items:center;justify-content:space-between;padding:18px 22px 14px;border-bottom:1px solid var(--brd)}
.modal-hdr h3{font-size:1rem;font-weight:700;display:flex;align-items:center;gap:8px}
.modal-hdr h3 i{color:var(--g)}
.modal-close{background:none;border:none;font-size:1.2rem;color:var(--gray);cursor:pointer;transition:.2s;padding:4px 8px;border-radius:4px}
.modal-close:hover{background:var(--bg);color:var(--bk)}
.modal-body{padding:20px 22px}
.modal-foot{padding:14px 22px;border-top:1px solid var(--brd);display:flex;gap:8px;justify-content:flex-end}



.form-group{margin-bottom:14px}
.form-group label{display:block;font-size:.78rem;font-weight:600;color:var(--gray);margin-bottom:4px}
.form-group input{width:100%;padding:9px 12px;border:1px solid var(--brd);border-radius:4px;font-family:var(--font);font-size:.88rem;transition:.2s}
.form-group input:focus{outline:none;border-color:var(--g);box-shadow:0 0 0 2px rgba(0,140,69,.15)}
.btn-primary{padding:10px 20px;background:var(--g);color:#fff;border:none;border-radius:4px;font-family:var(--font);font-size:.88rem;font-weight:600;cursor:pointer;transition:.2s;width:100%}
.btn-primary:hover{background:var(--gd)}
.btn-sec{padding:10px 20px;background:var(--bg);color:var(--gray);border:1px solid var(--brd);border-radius:4px;font-family:var(--font);font-size:.88rem;font-weight:600;cursor:pointer;transition:.2s}
.btn-sec:hover{background:var(--brd)}
.auth-msg{font-size:.8rem;padding:8px 12px;border-radius:4px;margin-top:10px;display:none}
.auth-msg.ok{background:#e3f2fd;color:#0D47A1;display:block}
.auth-msg.err{background:var(--rl);color:var(--r);display:block}

/* ── MODAL EXPORT ── */
#modal-export .modal-box{max-width:480px}
.export-cols{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:16px}
.export-col-item{display:flex;align-items:center;gap:8px;padding:7px 10px;border:1px solid var(--brd);border-radius:4px;cursor:pointer;transition:.15s;font-size:.84rem}
.export-col-item:hover{background:var(--gl);border-color:var(--g)}
.export-col-item input[type=checkbox]{accent-color:var(--g);width:15px;height:15px;cursor:pointer}
.export-col-item.checked{background:var(--gl);border-color:var(--g)}
.exp-fmt{display:flex;gap:8px;margin-bottom:12px}
.exp-fmt-btn{flex:1;padding:8px;border:1.5px solid var(--brd);border-radius:4px;background:var(--wh);font-family:var(--font);font-size:.82rem;font-weight:600;cursor:pointer;transition:.2s;text-align:center}
.exp-fmt-btn.active{border-color:var(--g);background:var(--gl);color:var(--g)}
.sel-btns{display:flex;gap:6px;margin-bottom:12px}
.sel-btns button{font-size:.75rem;padding:3px 10px;border:1px solid var(--brd);border-radius:4px;background:var(--bg);cursor:pointer;font-family:var(--font);transition:.2s}
.sel-btns button:hover{background:var(--gl);border-color:var(--g);color:var(--g)}

/* ── MODAL ADMIN ── */
#modal-admin .modal-box{max-width:800px;width:95vw}
.admin-tabs{display:flex;gap:0;border-bottom:2px solid var(--gl);margin-bottom:16px}
.admin-tab{padding:9px 18px;background:none;border:none;border-bottom:3px solid transparent;margin-bottom:-2px;font-family:var(--font);font-size:.84rem;font-weight:600;cursor:pointer;transition:.2s;color:var(--gray)}
.admin-tab.active{color:var(--g);border-bottom-color:var(--g)}
.admin-section{display:none}.admin-section.active{display:block}
.stat-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px;margin-bottom:16px}
.stat-card{background:var(--bg);border-radius:6px;padding:12px;text-align:center}
.stat-card .val{font-size:1.5rem;font-weight:700;color:var(--g)}
.stat-card .lbl{font-size:.7rem;color:var(--gray);text-transform:uppercase;letter-spacing:.4px}
.users-table{width:100%;border-collapse:collapse;font-size:.8rem}
.users-table th{background:var(--bg);padding:7px 10px;font-weight:700;font-size:.72rem;text-transform:uppercase;letter-spacing:.3px;border-bottom:2px solid var(--g);text-align:left}
.users-table td{padding:6px 10px;border-bottom:1px solid var(--brd)}
.users-table tr:hover td{background:var(--gl)}
.badge-role{padding:2px 8px;border-radius:10px;font-size:.69rem;font-weight:700}
.badge-admin{background:var(--yl);color:var(--yd)}
.badge-user{background:var(--gl);color:var(--gd)}
.admin-reload{background:var(--g);color:#fff;border:none;padding:9px 20px;border-radius:4px;font-family:var(--font);font-size:.85rem;font-weight:600;cursor:pointer;transition:.2s;display:flex;align-items:center;gap:7px}
.admin-reload:hover{background:var(--gd)}
.file-drop{border:2px dashed var(--brd);border-radius:var(--radius);padding:30px;text-align:center;cursor:pointer;transition:.2s;color:var(--gray)}
.file-drop:hover,.file-drop.drag{border-color:var(--g);background:var(--gl);color:var(--g)}
.file-drop i{font-size:2rem;margin-bottom:8px;display:block}

/* ── TOASTS ── */
#toast-container{position:fixed;top:20px;right:20px;z-index:9999;display:flex;flex-direction:column;gap:8px;pointer-events:none}
.toast{background:var(--wh);border-radius:8px;box-shadow:var(--sh-l);padding:12px 16px;min-width:260px;max-width:340px;display:flex;align-items:center;gap:10px;animation:tslide .3s ease;pointer-events:all;border-left:4px solid var(--g)}
.toast.err{border-left-color:var(--r)}
.toast.warn{border-left-color:var(--y)}
.toast i{font-size:1.1rem;flex-shrink:0}
.toast.ok i{color:var(--g)}
.toast.err i{color:var(--r)}
.toast.warn i{color:var(--yd)}
.toast-msg{font-size:.83rem;flex:1}
.toast-close{background:none;border:none;color:var(--gray);cursor:pointer;font-size:1rem;flex-shrink:0}
@keyframes tslide{from{transform:translateX(100%);opacity:0}to{transform:translateX(0);opacity:1}}

/* ── FOOTER ── */
footer{background:var(--bk);color:rgba(255,255,255,.5);text-align:center;padding:14px;font-size:.74rem;margin-top:24px;position:relative}
footer .fb{color:var(--y);font-weight:700}
.btn-admin-foot{position:absolute;right:20px;top:50%;transform:translateY(-50%);background:rgba(255,255,255,.1);color:rgba(255,255,255,.6);border:1px solid rgba(255,255,255,.2);padding:5px 13px;border-radius:4px;font-family:var(--font);font-size:.74rem;cursor:pointer;transition:.2s;display:flex;align-items:center;gap:6px}
.btn-admin-foot:hover{background:rgba(255,255,255,.2);color:#fff}

/* ── UX extras ── */
.tooltip-wrap{position:relative;display:inline-block}
.tooltip-wrap:hover .tooltip-txt{visibility:visible;opacity:1;transform:translateY(0)}
.tooltip-txt{visibility:hidden;opacity:0;background:var(--bk);color:#fff;font-size:.74rem;border-radius:4px;padding:4px 10px;position:absolute;bottom:130%;left:50%;transform:translateX(-50%) translateY(4px);white-space:nowrap;transition:.2s;z-index:100;pointer-events:none}
.tooltip-txt::after{content:"";position:absolute;top:100%;left:50%;transform:translateX(-50%);border:5px solid transparent;border-top-color:var(--bk)}


/* ── UX AMÉLIORATIONS SUPPLÉMENTAIRES ── */
/* Badge nombre résultats filtre */
.filter-badge{display:inline-flex;align-items:center;justify-content:center;background:var(--g);color:#fff;border-radius:10px;font-size:.65rem;font-weight:700;padding:1px 6px;margin-left:4px;min-width:18px}
/* Highlight filtre actif */
select[multiple]:focus option:checked{background:var(--g);color:#fff}
/* Input recherche avec icône */
.search-input-wrap{position:relative}
.search-input-wrap .search-icon{position:absolute;left:10px;top:50%;transform:translateY(-50%);color:var(--gray);pointer-events:none}
/* Bouton export désactivé */
.be:disabled{opacity:.45;cursor:not-allowed;transform:none!important}
/* Scroll smooth pour la base complète */
.db-scroll{scroll-behavior:smooth}
/* Surbrillance ligne hover plus douce */
tbody tr{cursor:default}
/* Tooltip sur badges PPE */
.br{cursor:help}
/* Animation KPI au chargement */
.kpi{animation:kpiFade .4s ease both}
.kpi:nth-child(1){animation-delay:.05s}
.kpi:nth-child(2){animation-delay:.1s}
.kpi:nth-child(3){animation-delay:.15s}
.kpi:nth-child(4){animation-delay:.2s}
.kpi:nth-child(5){animation-delay:.25s}
.kpi:nth-child(6){animation-delay:.3s}
@keyframes kpiFade{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
/* Bouton Réinitialiser amélioré */
.btn-rst{transition:.25s;letter-spacing:.2px}
.btn-rst:active{transform:scale(.97)}
/* Modal backdrop blur plus fort */
.modal-overlay{backdrop-filter:blur(6px)}
/* Input password avec toggle */
.pwd-wrap{position:relative}
.pwd-wrap input{padding-right:38px}
.pwd-toggle{position:absolute;right:10px;top:50%;transform:translateY(-50%);background:none;border:none;color:var(--gray);cursor:pointer;font-size:.95rem;padding:2px}
.pwd-toggle:hover{color:var(--g)}
/* Séparer section filtres actifs */
.active-filters-bar{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px;min-height:0}
.filter-tag{background:var(--gl);color:var(--gd);border:1px solid var(--g);border-radius:12px;padding:2px 8px;font-size:.72rem;font-weight:600;display:flex;align-items:center;gap:4px}
.filter-tag button{background:none;border:none;color:var(--g);cursor:pointer;font-size:.75rem;padding:0;line-height:1}
.filter-tag button:hover{color:var(--r)}
/* Footer amélioration */
footer{line-height:1.8}
/* Réseau instructions */
.net-help{background:var(--gl);border-radius:6px;padding:8px 12px;font-size:.78rem;color:var(--gd);margin-bottom:8px;display:flex;align-items:flex-start;gap:8px}
.net-help i{margin-top:2px;flex-shrink:0}
/* Admin stat card hover */
.stat-card{transition:.2s;cursor:default}
.stat-card:hover{box-shadow:var(--sh-s);transform:translateY(-1px)}
/* Placeholder style */
::placeholder{color:#bbb;font-style:italic}
/* Focus visible pour accessibilité */
button:focus-visible,select:focus-visible,input:focus-visible{outline:2px solid var(--y);outline-offset:2px}
"""

    BODY = f"""
<!-- TOAST CONTAINER -->
<div id="toast-container"></div>

<!-- HEADER -->
<div id="hdr">
  <div class="hi">
    <img src="data:image/png;base64,{logo_b64}" alt="ITIE Sénégal">
    <div class="hi-sep"></div>
    <div class="hi-t">
      <div class="brand"><span>Open</span>RBE</div>
      <div class="sub">Open Registre des Bénéficiaires Effectifs</div>
      <div class="tag">Plateforme nationale de consultation du secteur extractif sénégalais</div>
    </div>
    <div class="hdr-right">
      <div class="badge"><i class="fas fa-shield-halved"></i> Données officielles ITIE</div>
    </div>
  </div>
  <nav class="nav-bar"><ul>
    <li><a href="#" class="active" data-page="dashboard"><i class="fas fa-gauge-high"></i> Tableau de bord</a></li>
    <li><a href="#" data-page="database"><i class="fas fa-database"></i> Base complète</a></li>
    <li><a href="#" data-page="search"><i class="fas fa-magnifying-glass"></i> Recherche</a></li>
    <li><a href="#" data-page="ppe"><i class="fas fa-user-shield"></i> Analyse PPE</a></li>
    <li><a href="#" data-page="network"><i class="fas fa-diagram-project"></i> Réseaux</a></li>
    <li><a href="#" data-page="map"><i class="fas fa-map-location-dot"></i> Cartographie</a></li>
  </ul></nav>
</div>

<!-- APP -->
<div id="app">
<div id="sb">
  <div class="sb-ttl"><i class="fas fa-filter"></i> Filtres globaux</div>

  <!-- Réinitialiser EN HAUT -->
  <button class="btn-rst" onclick="resetF()"><i class="fas fa-rotate-left"></i> Réinitialiser tous les filtres</button>
  <div id="active-filters-bar" class="active-filters-bar" style="margin-top:6px"></div>

  <div class="fb"><label class="fl">Région</label>
    <select id="fr" multiple></select>
  </div>
  <div class="fb"><label class="fl">Nationalité</label>
    <select id="fn" multiple></select>
  </div>
  <div class="fb"><label class="fl">Pays de résidence</label>
    <select id="fp" multiple></select>
  </div>
  <div class="fb"><label class="fl">Greffe</label>
    <select id="fg"><option value="">Tous</option></select>
  </div>
  <div class="fb"><label class="fl">Statut PPE</label>
    <div class="sw-row">PPE uniquement <label class="tog"><input type="checkbox" id="fppe"><span class="ts"></span></label></div>
  </div>
  <div class="fb"><label class="fl">% Action Direct</label>
    <input type="range" id="fpmin" min="0" max="100" value="0" step="5">
    <input type="range" id="fpmax" min="0" max="100" value="100" step="5" style="margin-top:3px">
    <div class="rr"><span id="lpmin">0%</span><span id="lpmax">100%</span></div>
  </div>

  <div class="sc">
    <div class="sc-v" id="scn">{n_total}</div>
    <div class="sc-l">bénéficiaires affichés</div>
    <div class="sc-p" id="scp">100% du total</div>
  </div>
  <div class="src-info">
    <strong>Source :</strong> {excel_filename}<br>
    Généré le {build_time}<br>
    <span style="color:var(--gd);font-weight:600">{n_total} enregistrements</span>
  </div>
</div>

<div id="ct">

<!-- DASHBOARD -->
<div class="page active" id="page-dashboard">
  <div class="kr">
    <div class="kpi" style="border-top-color:var(--g)"><div class="ki" style="color:var(--g)"><i class="fas fa-building"></i></div><div><div class="kv" id="k-co">-</div><div class="kl">Entreprises</div></div></div>
    <div class="kpi" style="border-top-color:var(--b)"><div class="ki" style="color:var(--b)"><i class="fas fa-users"></i></div><div><div class="kv" id="k-be">-</div><div class="kl">Bénéficiaires</div></div></div>
    <div class="kpi" style="border-top-color:var(--gd)"><div class="ki" style="color:var(--gd)"><i class="fas fa-calculator"></i></div><div><div class="kv" id="k-av">-</div><div class="kl">Moy./entreprise</div></div></div>
    <div class="kpi" style="border-top-color:var(--r)"><div class="ki" style="color:var(--r)"><i class="fas fa-user-shield"></i></div><div><div class="kv" id="k-pp">-</div><div class="kl">PPE</div></div></div>
    <div class="kpi" style="border-top-color:var(--yd)"><div class="ki" style="color:var(--yd)"><i class="fas fa-flag"></i></div><div><div class="kv" id="k-na">-</div><div class="kl">Nationalités</div></div></div>
    <div class="kpi" style="border-top-color:var(--b)"><div class="ki" style="color:var(--b)"><i class="fas fa-globe"></i></div><div><div class="kv" id="k-pa">-</div><div class="kl">Pays résidence</div></div></div>
  </div>
  <div class="g2">
    <div class="card"><div class="ct"><i class="fas fa-globe-africa"></i> Répartition par nationalité (Top 15)</div><div class="cw"><canvas id="ch-nat"></canvas></div></div>
    <div class="card"><div class="ct"><i class="fas fa-user-tie"></i> Statut PPE</div><div class="cw"><canvas id="ch-ppe"></canvas></div></div>
  </div>
  <div class="g2">
    <div class="card"><div class="ct"><i class="fas fa-map-marker-alt"></i> Répartition régionale</div><div class="cw"><canvas id="ch-reg"></canvas></div></div>
    <div class="card"><div class="ct"><i class="fas fa-chart-bar"></i> Distribution des participations (%)</div><div class="cw"><canvas id="ch-pct"></canvas></div></div>
  </div>
  <div class="card" style="position:relative">
    <div class="ct">
      <i class="fas fa-building"></i> Top 30 entreprises
      <button class="be bxl" style="margin-left:auto" onclick="openExportModal('top')">
        <i class="fas fa-file-export"></i> Exporter avec sélection
      </button>
    </div>
    <div class="tw"><table id="tbl-top"><thead><tr><th>Entreprise</th><th>Région</th><th>Greffe</th><th>Bénéficiaires</th><th>Part. moy.</th><th>PPE</th></tr></thead><tbody></tbody></table></div>
  </div>
</div>

<!-- BASE COMPLÈTE -->
<div class="page" id="page-database">
  <div class="card" style="position:relative">
    <div class="ct">
      <i class="fas fa-database"></i> Base complète des bénéficiaires effectifs
      <span style="margin-left:auto;font-size:.77rem;color:var(--gray);font-weight:400" id="db-count-lbl"></span>
    </div>
    <div class="eb">
      <button class="be bxl" onclick="openExportModal('db')"><i class="fas fa-file-export"></i> Exporter avec sélection</button>
    </div>
    <div class="db-toolbar">
      <input type="text" id="db-search" placeholder="🔍  Rechercher dans toute la base...">
    </div>
    <div class="db-info" id="db-info"></div>
    <div class="db-scroll">
      <table id="tbl-db">
        <thead><tr>
          <th style="width:38px">#</th><th>Dénomination Sociale</th><th>Bénéficiaire</th>
          <th>Région</th><th>Nationalité</th><th>Pays résidence</th>
          <th>% Action</th><th>% Voix</th><th>PPE</th>
          <th>Fonction PPE</th><th>Nom PPE lié</th><th>Greffe</th>
          <th>Date acquisition</th><th>Année</th>
        </tr></thead>
        <tbody id="db-tbody"></tbody>
      </table>
    </div>
    <div class="pg-bar">
      <button class="pg-btn" id="pg-prev" onclick="dbNav(-1)"><i class="fas fa-chevron-left"></i></button>
      <div id="pg-pages" style="display:flex;gap:4px;flex-wrap:wrap"></div>
      <button class="pg-btn" id="pg-next" onclick="dbNav(1)"><i class="fas fa-chevron-right"></i></button>
      <span class="pg-info" id="pg-info"></span>
      <select class="pg-sz" id="pg-sz" onchange="dbSzChange()">
        <option value="25">25/page</option><option value="50" selected>50/page</option>
        <option value="100">100/page</option><option value="9999">Tout</option>
      </select>
    </div>
  </div>
</div>

<!-- RECHERCHE -->
<div class="page" id="page-search">

  <!-- Onglets Entreprise / Bénéficiaire -->
  <div class="search-tabs">
    <button class="search-tab active" id="stab-co" onclick="switchSearchTab('co')">
      <i class="fas fa-building"></i> Recherche Entreprise
    </button>
    <button class="search-tab" id="stab-be" onclick="switchSearchTab('be')">
      <i class="fas fa-user"></i> Recherche Bénéficiaire
    </button>
  </div>

  <!-- Panneau Entreprise -->
  <div id="spane-co">
    <div class="shero">
      <h3><i class="fas fa-building"></i> Recherche d'entreprise</h3>
      <p>Tapez les premiers caractères — seules les entreprises de la base RBE sont proposées.</p>
      <div class="sw">
        <input type="text" id="si" placeholder="Nom de l'entreprise...">
        <div id="sdd"></div>
      </div>
    </div>
    <div id="ccw"></div>
  </div>

  <!-- Panneau Bénéficiaire -->
  <div id="spane-be" style="display:none">
    <div class="shero" style="background:linear-gradient(135deg,var(--b) 0%,var(--bd) 100%)">
      <h3><i class="fas fa-user"></i> Recherche de bénéficiaire effectif</h3>
      <p>Tapez le nom ou prénom — tous les bénéficiaires de la base RBE sont proposés.</p>
      <div class="sw">
        <input type="text" id="si-be" placeholder="Nom ou prénom du bénéficiaire...">
        <div id="sdd-be"></div>
      </div>
    </div>
    <div id="bcw"></div>
  </div>

</div>

<!-- PPE -->
<div class="page" id="page-ppe">
  <div class="pkr" id="ppe-kpis"></div>
  <div class="g2">
    <div class="card"><div class="ct"><i class="fas fa-flag"></i> PPE par nationalité</div><div class="cwsm"><canvas id="ch-pn"></canvas></div></div>
    <div class="card"><div class="ct"><i class="fas fa-map-marker-alt"></i> PPE par région</div><div class="cwsm"><canvas id="ch-pr"></canvas></div></div>
  </div>
  <div class="card" style="position:relative">
    <div class="ct">
      <i class="fas fa-user-tie"></i> Liste complète des PPE
      <button class="be bxl" style="margin-left:auto" onclick="openExportModal('ppe')"><i class="fas fa-file-export"></i> Exporter</button>
    </div>
    <div class="tw"><table id="tbl-ppe"><thead><tr>
      <th>Bénéficiaire</th><th>Entreprise</th><th>Région</th><th>Nationalité</th>
      <th>Pays résidence</th><th>% Action</th><th>% Voix</th><th>Fonction PPE</th><th>Nom PPE lié</th>
    </tr></thead><tbody></tbody></table></div>
  </div>
</div>

<!-- RÉSEAU -->
<div class="page" id="page-network">
  <div class="card">
    <div class="ct"><i class="fas fa-diagram-project"></i> Réseau de propriété effective</div>
    <div class="nc">
      <div class="nsg"><label class="gl"><span class="ld lg" style="display:inline-block;margin-right:3px"></span> Choisir une Entreprise</label><select id="ns-co" class="gs" onchange="focusNode(this.value,'co')"><option value="">— Toutes —</option></select></div>
      <div class="nsg"><label class="yl"><span class="ld ly" style="display:inline-block;margin-right:3px"></span> Choisir un Bénéficiaire</label><select id="ns-be" class="ys" onchange="focusNode(this.value,'be')"><option value="">— Tous —</option></select></div>
      <div class="nsg" style="max-width:155px"><label style="color:var(--gray)">Nb max entreprises</label><select id="nmx" onchange="buildNet()"><option value="10">10</option><option value="20" selected>20</option><option value="30">30</option><option value="50">50</option></select></div>
      <button class="nb gn" onclick="buildNet()"><i class="fas fa-sync"></i> Rafraîchir</button>
    </div>
    <div class="nleg"><span class="ld lg"></span> Entreprise &nbsp; <span class="ld ly"></span> Bénéficiaire</div>
    <div id="nib" style="display:none" class="nib"></div>
    <div class="net-help"><i class="fas fa-lightbulb"></i> Utilisez les listes déroulantes pour cibler une entreprise ou un bénéficiaire — le graphe zoome automatiquement. Survolez un noeud pour voir son nom complet. Glissez pour déplacer, molette pour zoomer.</div>
    <div id="nwrap"><svg id="nsvg"></svg></div>
    <div class="ntip"><i class="fas fa-info-circle"></i> Cliquez ou utilisez les listes pour zoomer sur un noeud. Molette pour zoomer. Glisser pour déplacer.</div>
  </div>
</div>

<!-- CARTE -->
<div class="page" id="page-map">
  <div class="card">
    <div class="ct"><i class="fas fa-map"></i> Cartographie des entreprises extractives au Sénégal</div>
    <div style="margin-bottom:10px;display:flex;gap:14px;align-items:center;flex-wrap:wrap">
      <label style="font-size:.8rem;font-weight:600;color:var(--gray)">Indicateur :</label>
      <label style="font-size:.81rem"><input type="radio" name="mm" value="nb" checked> Bénéficiaires</label>
      <label style="font-size:.81rem"><input type="radio" name="mm" value="ne"> Entreprises</label>
      <label style="font-size:.81rem"><input type="radio" name="mm" value="np"> PPE</label>
    </div>
    <div id="map"></div>
    <div class="ntip" style="margin-top:7px"><i class="fas fa-info-circle"></i> Carte verrouillée sur le Sénégal. Cliquez un cercle pour le détail.</div>
  </div>
  <div class="card">
    <div class="ct"><i class="fas fa-table"></i> Récapitulatif par région</div>
    <div class="tw"><table id="tbl-reg"><thead><tr><th>Région</th><th>Entreprises</th><th>Bénéficiaires</th><th>dont PPE</th></tr></thead><tbody></tbody></table></div>
  </div>
</div>

</div></div>

<!-- FOOTER -->
<footer>
  <span class="fb">OpenRBE</span> — Open Registre des Bénéficiaires Effectifs |
  © ITIE Sénégal 2025 | Initiative pour la Transparence dans les Industries Extractives<br>
  <span style="opacity:.35">Généré le {build_time} depuis <em>{excel_filename}</em> · {n_total} enregistrements</span>
  <button class="btn-admin-foot" onclick="openAdmin()">
    <i class="fas fa-user-shield"></i> Administrateur
  </button>
</footer>

<!-- ══ MODAL EXPORT<!-- ══ MODAL EXPORT ══ -->
<div class="modal-overlay hidden" id="modal-export" onclick="closeOnBg(event,'modal-export')">
  <div class="modal-box" style="max-width:500px">
    <div class="modal-hdr">
      <h3><i class="fas fa-file-export"></i> Exporter les données</h3>
      <button class="modal-close" onclick="closeModal('modal-export')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body">
      <p style="font-size:.83rem;color:var(--gray);margin-bottom:14px">Sélectionnez les colonnes à inclure dans l'export :</p>
      <div class="sel-btns">
        <button onclick="exportSelAll(true)">Tout sélectionner</button>
        <button onclick="exportSelAll(false)">Tout désélectionner</button>
      </div>
      <div class="export-cols" id="export-cols"></div>
      <p style="font-size:.82rem;font-weight:600;margin-bottom:8px;color:var(--bk)">Format :</p>
      <div class="exp-fmt">
        <button class="exp-fmt-btn active" id="fmt-csv" onclick="setFmt('csv')"><i class="fas fa-file-csv"></i> CSV</button>
        <button class="exp-fmt-btn" id="fmt-json" onclick="setFmt('json')"><i class="fas fa-code"></i> JSON</button>
      </div>
      <p style="font-size:.75rem;color:var(--gray)" id="export-count-info"></p>
    </div>
    <div class="modal-foot">
      <button class="btn-sec" onclick="closeModal('modal-export')">Annuler</button>
      <button class="btn-primary" style="width:auto;padding:9px 22px" onclick="doExport()">
        <i class="fas fa-download"></i> Télécharger
      </button>
    </div>
  </div>
</div>

<!-- ══ MODAL ADMIN ══ -->
<div class="modal-overlay hidden" id="modal-admin" onclick="closeOnBg(event,'modal-admin')">
  <div class="modal-box" style="max-width:820px;width:95vw">
    <div class="modal-hdr">
      <h3><i class="fas fa-user-shield"></i> Interface Administrateur</h3>
      <button class="modal-close" onclick="closeModal('modal-admin')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body">
      <!-- Dashboard admin (accès direct) -->
      <div id="admin-dash">
        <div class="admin-tabs">
          <button class="admin-tab active" onclick="switchAdminTab('stats')"><i class="fas fa-chart-pie"></i> Statistiques</button>
          <button class="admin-tab" onclick="switchAdminTab('users')"><i class="fas fa-users"></i> Utilisateurs</button>
          <button class="admin-tab" onclick="switchAdminTab('exports')"><i class="fas fa-history"></i> Historique exports</button>
          <button class="admin-tab" onclick="switchAdminTab('update')"><i class="fas fa-upload"></i> Actualiser les données</button>
        </div>
        <!-- Stats -->
        <div class="admin-section active" id="asec-stats">
          <div class="stat-cards" id="admin-stat-cards"></div>
        </div>
        <!-- Utilisateurs -->
        <div class="admin-section" id="asec-users">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
            <p style="font-size:.83rem;color:var(--gray)">Comptes enregistrés sur la plateforme.</p>
            <button class="be bcsv" onclick="exportAdminUsers()"><i class="fas fa-file-csv"></i> Exporter CSV</button>
          </div>
          <div style="overflow-x:auto">
            <table class="users-table" id="admin-users-table">
              <thead><tr><th>#</th><th>Prénom</th><th>Nom</th><th>Email</th><th>Organisation</th><th>Rôle</th><th>Inscription</th></tr></thead>
              <tbody id="admin-users-body"></tbody>
            </table>
          </div>
        </div>
        <!-- Historique exports -->
        <div class="admin-section" id="asec-exports">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
            <p style="font-size:.83rem;color:var(--gray)">Tous les exports effectués par les utilisateurs.</p>
            <button class="be bcsv" onclick="exportAdminExports()"><i class="fas fa-file-csv"></i> Exporter CSV</button>
          </div>
          <div style="overflow-x:auto">
            <table class="users-table" id="admin-exp-table">
              <thead><tr><th>#</th><th>Date</th><th>Utilisateur</th><th>Email</th><th>Section</th><th>Format</th><th>Colonnes</th><th>Nb lignes</th></tr></thead>
              <tbody id="admin-exp-body"></tbody>
            </table>
          </div>
        </div>
        <!-- Actualiser données -->
        <div class="admin-section" id="asec-update">
          <p style="font-size:.83rem;color:var(--gray);margin-bottom:16px">
            Pour actualiser les données, lancez <strong>build.py</strong> depuis votre ordinateur après avoir mis à jour le fichier Excel.<br>
            Cela régénère automatiquement <code>index.html</code> avec les nouvelles données.
          </p>
          <div class="file-drop" id="admin-file-drop">
            <i class="fas fa-file-excel" style="color:var(--g)"></i>
            <strong style="display:block;margin-bottom:5px">Procédure de mise à jour</strong>
            <ol style="text-align:left;display:inline-block;font-size:.82rem;color:var(--gray);margin-top:8px;line-height:2">
              <li>Remplacez <code>data/RBE-2021-A-2025.xlsx</code> par la nouvelle version</li>
              <li>Double-cliquez sur <code>LANCER_WINDOWS.bat</code> ou <code>LANCER_MAC_LINUX.sh</code></li>
              <li>L'application se régénère et s'ouvre automatiquement</li>
            </ol>
          </div>
          <div style="margin-top:14px;padding:12px;background:var(--yl);border-radius:6px;font-size:.81rem;color:var(--yd)">
            <i class="fas fa-info-circle"></i> Source actuelle : <strong>{excel_filename}</strong> — générée le <strong>{build_time}</strong> — <strong>{n_total} enregistrements</strong>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
"""

    JS = """
const DB=__DATA__;
const COORDS={"Dakar":[14.693,-17.447],"Thiès":[14.788,-16.924],"Diourbel":[14.655,-16.232],"Fatick":[14.339,-16.411],"Kaolack":[14.152,-16.073],"Kédougou":[12.560,-12.186],"Mbour":[14.408,-16.965],"Tambacounda":[13.771,-13.667],"Ziguinchor":[12.565,-16.272],"Louga":[15.617,-16.224],"Saint-Louis":[16.028,-16.499],"Matam":[15.658,-13.263],"Kolda":[12.886,-14.944],"Sédhiou":[12.708,-15.557],"Kaffrine":[14.106,-15.551]};
const CL={g:'#1565C0',gd:'#0D47A1',y:'#F4C300',yd:'#B89300',r:'#D62D20',b:'#005A8E'};
const NR='<span class="nr">—</span>';
const v=x=>(!x&&x!==0)?NR:x;
const vp=x=>(!x&&x!==0)?NR:x+'%';
const fmt=n=>Number(n).toLocaleString('fr-FR');
let FD=[...DB],charts={},leafMap=null,nNodes=[],nLinks=[],nZoom=null,nSvg=null;
let dbF=[...DB],dbPg=1,dbSz=50,dbQ='';

/* ═══════════════════════════════════════════
   INDEXEDDB — Stockage local des utilisateurs et exports
═══════════════════════════════════════════ */
const DB_NAME='OpenRBE_DB', DB_VER=1;
let idb=null;
function openIDB(){
  return new Promise((res,rej)=>{
    const req=indexedDB.open(DB_NAME,DB_VER);
    req.onupgradeneeded=e=>{
      const db=e.target.result;
      if(!db.objectStoreNames.contains('users')){
        const us=db.createObjectStore('users',{keyPath:'email'});
        us.createIndex('email','email',{unique:true});
      }
      if(!db.objectStoreNames.contains('exports')){
        const es=db.createObjectStore('exports',{keyPath:'id',autoIncrement:true});
        es.createIndex('userEmail','userEmail',{unique:false});
      }
    };
    req.onsuccess=e=>{idb=e.target.result;res(idb);};
    req.onerror=rej;
  });
}
function idbGet(store,key){return new Promise((res,rej)=>{const tx=idb.transaction(store,'readonly');tx.objectStore(store).get(key).onsuccess=e=>res(e.target.result);tx.onerror=rej;});}
function idbPut(store,obj){return new Promise((res,rej)=>{const tx=idb.transaction(store,'readwrite');tx.objectStore(store).put(obj).onsuccess=e=>res(e.target.result);tx.onerror=rej;});}
function idbGetAll(store){return new Promise((res,rej)=>{const tx=idb.transaction(store,'readonly');tx.objectStore(store).getAll().onsuccess=e=>res(e.target.result);tx.onerror=rej;});}

/* ═══════════════════════════════════════════
   ADMIN — MOT DE PASSE
═══════════════════════════════════════════ */
const ADMIN_PWD='ITIE2025admin';

function hashPwd(s){
  let h=0;for(let i=0;i<s.length;i++){h=(Math.imul(31,h)+s.charCodeAt(i))|0;}
  return h.toString(36);
}

/* ═══════════════════════════════════════════
   MODAL EXPORT — Sélection de colonnes
═══════════════════════════════════════════ */
const ALL_COLS=[
  {key:'ds',lbl:'Dénomination Sociale'},{key:'pn',lbl:'Bénéficiaire'},
  {key:'rs',lbl:'Région'},{key:'na',lbl:'Nationalité'},
  {key:'pr',lbl:'Pays résidence'},{key:'pa',lbl:'% Action Direct'},
  {key:'pv',lbl:'% Voix Direct'},{key:'pp',lbl:'PPE'},
  {key:'fp',lbl:'Fonction PPE'},{key:'np',lbl:'Nom PPE lié'},
  {key:'gr',lbl:'Greffe'},{key:'da',lbl:'Date acquisition'},
  {key:'an',lbl:'Année'},
];
let exportSource='top', exportFmt='csv';

function openExportModal(src){
  exportSource=src;
  const srcData=getExportRows(src);
  document.getElementById('export-count-info').textContent=`${fmt(srcData.length)} ligne(s) à exporter`;
  const cols=document.getElementById('export-cols');
  cols.innerHTML=ALL_COLS.map(c=>`
    <label class="export-col-item checked" id="ecol-${c.key}">
      <input type="checkbox" checked value="${c.key}" onchange="toggleExportCol('${c.key}',this.checked)">
      ${c.lbl}
    </label>`).join('');
  setFmt('csv');
  openModal('modal-export');
}

function toggleExportCol(key,checked){
  document.getElementById('ecol-'+key).classList.toggle('checked',checked);
}

function exportSelAll(val){
  document.querySelectorAll('#export-cols input[type=checkbox]').forEach(cb=>{
    cb.checked=val;
    const key=cb.value;
    document.getElementById('ecol-'+key).classList.toggle('checked',val);
  });
}

function setFmt(f){
  exportFmt=f;
  document.getElementById('fmt-csv').classList.toggle('active',f==='csv');
  document.getElementById('fmt-json').classList.toggle('active',f==='json');
}

function getExportRows(src){
  if(src==='ppe') return FD.filter(r=>r.pp);
  if(src==='db')  return dbF;
  return compS(FD).slice(0,30);
}

async function doExport(){
  const selectedKeys=[...document.querySelectorAll('#export-cols input:checked')].map(cb=>cb.value);
  if(!selectedKeys.length){showToast('Sélectionnez au moins une colonne.','warn','fa-exclamation-triangle');return;}
  const colDefs=ALL_COLS.filter(c=>selectedKeys.includes(c.key));
  const rawRows=getExportRows(exportSource);
  const rows=rawRows.map(r=>{
    const o={};
    colDefs.forEach(c=>{
      let val=r[c.key];
      if(c.key==='pp') val=val?'Oui':'Non';
      o[c.lbl]=val??'';
    });
    return o;
  });

  const fname=`openrbe_export_${exportSource}_${new Date().toISOString().slice(0,10)}`;
  if(exportFmt==='json'){
    const b=new Blob([JSON.stringify(rows,null,2)],{type:'application/json'});
    dlBlob(b,fname+'.json');
  } else {
    exportCSV(rows,fname);
  }

  // Enregistrer dans IndexedDB (accès libre — sans info utilisateur)
  await idbPut('exports',{
    userEmail:'anonyme',
    userName:'Utilisateur',
    section:exportSource,
    format:exportFmt,
    columns:colDefs.map(c=>c.lbl).join(', '),
    nbRows:rows.length,
    exportedAt:new Date().toISOString()
  });

  closeModal('modal-export');
  showToast(`Export réussi — ${fmt(rows.length)} lignes téléchargées.`,'ok','fa-check-circle');
}

/* ═══════════════════════════════════════════
   ADMIN
═══════════════════════════════════════════ */
let adminUnlocked=false;

function openAdmin(){openModal('modal-admin');if(!adminUnlocked){document.getElementById('admin-login-pane').style.display='block';document.getElementById('admin-dash').style.display='none';}}

function doAdminLogin(){
  const pwd=document.getElementById('admin-pwd').value;
  const msg=document.getElementById('admin-msg');
  if(pwd===ADMIN_PWD){
    adminUnlocked=true;
    document.getElementById('admin-login-pane').style.display='none';
    document.getElementById('admin-dash').style.display='block';
    loadAdminDash();
  } else {
    msg.className='auth-msg err';msg.textContent='Mot de passe incorrect.';
  }
}

function switchAdminTab(tab){
  document.querySelectorAll('.admin-tab').forEach((b,i)=>{
    const tabs=['stats','users','exports','update'];
    b.classList.toggle('active',tabs[i]===tab);
  });
  document.querySelectorAll('.admin-section').forEach(s=>s.classList.remove('active'));
  document.getElementById('asec-'+tab).classList.add('active');
}

async function loadAdminDash(){
  const users=await idbGetAll('users');
  const exports2=await idbGetAll('exports');
  // Stats
  document.getElementById('admin-stat-cards').innerHTML=[
    {val:users.length,lbl:'Utilisateurs inscrits',c:'var(--g)'},
    {val:exports2.length,lbl:'Exports effectués',c:'var(--b)'},
    {val:exports2.filter(e=>e.section==='db').length,lbl:'Exports base complète',c:'var(--r)'},
    {val:users.filter(u=>u.role==='admin').length,lbl:'Administrateurs',c:'var(--yd)'},
  ].map(s=>`<div class="stat-card"><div class="val" style="color:${s.c}">${s.val}</div><div class="lbl">${s.lbl}</div></div>`).join('');
  // Utilisateurs
  const ub=document.getElementById('admin-users-body');
  ub.innerHTML=users.length?users.map((u,i)=>`<tr>
    <td>${i+1}</td><td>${u.prenom}</td><td>${u.nom}</td>
    <td><a href="mailto:${u.email}">${u.email}</a></td>
    <td>${u.org||'—'}</td>
    <td><span class="badge-role badge-${u.role}">${u.role}</span></td>
    <td>${new Date(u.createdAt).toLocaleDateString('fr-FR')}</td>
  </tr>`).join(''):'<tr><td colspan="7" style="text-align:center;color:var(--gray);padding:16px">Aucun utilisateur inscrit</td></tr>';
  // Exports
  const eb=document.getElementById('admin-exp-body');
  const sorted=[...exports2].sort((a,b)=>new Date(b.exportedAt)-new Date(a.exportedAt));
  eb.innerHTML=sorted.length?sorted.map((e,i)=>`<tr>
    <td>${i+1}</td>
    <td>${new Date(e.exportedAt).toLocaleString('fr-FR')}</td>
    <td>${e.userName}</td>
    <td>${e.userEmail}</td>
    <td><span class="badge-role badge-user">${e.section}</span></td>
    <td>${e.format.toUpperCase()}</td>
    <td style="font-size:.73rem;max-width:180px;white-space:normal">${e.columns}</td>
    <td>${fmt(e.nbRows)}</td>
  </tr>`).join(''):'<tr><td colspan="8" style="text-align:center;color:var(--gray);padding:16px">Aucun export enregistré</td></tr>';
}

async function exportAdminUsers(){
  const users=await idbGetAll('users');
  exportCSV(users.map(u=>({'Prénom':u.prenom,'Nom':u.nom,'Email':u.email,'Organisation':u.org||'','Rôle':u.role,'Inscription':new Date(u.createdAt).toLocaleString('fr-FR')})),'admin_utilisateurs');
}

async function exportAdminExports(){
  const exports2=await idbGetAll('exports');
  exportCSV(exports2.map(e=>({'Date':new Date(e.exportedAt).toLocaleString('fr-FR'),'Utilisateur':e.userName,'Email':e.userEmail,'Section':e.section,'Format':e.format,'Colonnes':e.columns,'Nb lignes':e.nbRows})),'admin_historique_exports');
}

/* ═══════════════════════════════════════════
   MODAUX UTILITAIRES
═══════════════════════════════════════════ */
function openModal(id){document.getElementById(id).classList.remove('hidden');document.body.style.overflow='hidden';}
function closeModal(id){document.getElementById(id).classList.add('hidden');document.body.style.overflow='';}
function closeOnBg(e,id){if(e.target===document.getElementById(id))closeModal(id);}


/* ═══════════════════════════════════════════
   TOAST NOTIFICATIONS
═══════════════════════════════════════════ */
function showToast(msg,type='ok',icon='fa-info-circle'){
  const c=document.getElementById('toast-container');
  const t=document.createElement('div');
  t.className='toast '+type;
  t.innerHTML=`<i class="fas ${icon}"></i><span class="toast-msg">${msg}</span><button class="toast-close" onclick="this.parentElement.remove()"><i class="fas fa-times"></i></button>`;
  c.appendChild(t);
  setTimeout(()=>t.style.animation='tslide .3s ease reverse',3200);
  setTimeout(()=>t.remove(),3500);
}

/* ═══════════════════════════════════════════
   NAV
═══════════════════════════════════════════ */
document.querySelectorAll('.nav-bar a').forEach(a=>{
  a.addEventListener('click',e=>{
    e.preventDefault();
    document.querySelectorAll('.nav-bar a').forEach(x=>x.classList.remove('active'));
    document.querySelectorAll('.page').forEach(x=>x.classList.remove('active'));
    a.classList.add('active');
    const pg=a.dataset.page;
    document.getElementById('page-'+pg).classList.add('active');
    if(pg==='map'&&!leafMap)initMap();
    if(pg==='network')buildNet();
    if(pg==='ppe')renderPPE();
    if(pg==='database')renderDB();
  });
});

/* ═══════════════════════════════════════════
   FILTRES
═══════════════════════════════════════════ */
function popF(){
  const addMulti=(id,arr)=>{
    const el=document.getElementById(id);
    el.innerHTML='';
    arr.forEach(x=>{const o=document.createElement('option');o.value=x;o.textContent=x;el.appendChild(o);});
  };
  addMulti('fr',[...new Set(DB.map(r=>r.rs).filter(Boolean))].sort());
  addMulti('fn',[...new Set(DB.map(r=>r.na).filter(Boolean))].sort());
  addMulti('fp',[...new Set(DB.map(r=>r.pr).filter(Boolean))].sort());
  const g=document.getElementById('fg');
  g.innerHTML='<option value="">Tous</option>';
  [...new Set(DB.map(r=>r.gr).filter(Boolean))].sort().forEach(x=>{
    const o=document.createElement('option');o.value=x;o.textContent=x;g.appendChild(o);
  });
}

function sv(id){return[...document.getElementById(id).selectedOptions].map(o=>o.value).filter(Boolean);}

function applyF(){
  const rs=sv('fr'),na=sv('fn'),pr=sv('fp'),gr=document.getElementById('fg').value;
  const pp=document.getElementById('fppe').checked;
  const mn=+document.getElementById('fpmin').value,mx=+document.getElementById('fpmax').value;
  FD=DB.filter(r=>{
    if(rs.length&&!rs.includes(r.rs))return false;
    if(na.length&&!na.includes(r.na))return false;
    if(pr.length&&!pr.includes(r.pr))return false;
    if(gr&&r.gr!==gr)return false;
    if(pp&&!r.pp)return false;
    if(r.pa!==null&&(r.pa<mn||r.pa>mx))return false;
    return true;
  });
  document.getElementById('scn').textContent=fmt(FD.length);
  document.getElementById('scp').textContent=Math.round(100*FD.length/DB.length)+'% du total';
  renderAll();
  updateActiveTags();
  updateSidebarCount();
}

['fr','fn','fp','fg'].forEach(id=>document.getElementById(id).addEventListener('change',applyF));
document.getElementById('fppe').addEventListener('change',applyF);
[['fpmin','lpmin'],['fpmax','lpmax']].forEach(([id,l])=>{
  document.getElementById(id).addEventListener('input',function(){document.getElementById(l).textContent=this.value+'%';applyF();});
});

function resetF(){
  ['fr','fn','fp'].forEach(id=>[...document.getElementById(id).options].forEach(o=>o.selected=false));
  document.getElementById('fg').value='';
  document.getElementById('fppe').checked=false;
  document.getElementById('fpmin').value=0;document.getElementById('lpmin').textContent='0%';
  document.getElementById('fpmax').value=100;document.getElementById('lpmax').textContent='100%';
  applyF();
  updateActiveTags();
  showToast('Filtres réinitialisés','ok','fa-rotate-left');
}

/* ═══════════════════════════════════════════
   ANALYTICS
═══════════════════════════════════════════ */
function stats(d){
  const co=[...new Set(d.map(r=>r.ds).filter(Boolean))];
  const pp=d.filter(r=>r.pp);
  return{co,pp,na:[...new Set(d.map(r=>r.na).filter(Boolean))],pr:[...new Set(d.map(r=>r.pr).filter(Boolean))],avg:co.length?(d.length/co.length).toFixed(1):'—',total:d.length};
}
function compS(d){
  const m={};
  d.forEach(r=>{if(!r.ds)return;if(!m[r.ds])m[r.ds]={ds:r.ds,rs:r.rs,gr:r.gr,n:0,pcts:[],ppe:0};m[r.ds].n++;if(r.pa!==null)m[r.ds].pcts.push(r.pa);if(r.pp)m[r.ds].ppe++;});
  return Object.values(m).map(c=>({...c,avg:c.pcts.length?+(c.pcts.reduce((a,b)=>a+b,0)/c.pcts.length).toFixed(1):null})).sort((a,b)=>b.n-a.n);
}
function regS(d){
  const m={};
  d.forEach(r=>{if(!r.rs)return;if(!m[r.rs])m[r.rs]={region:r.rs,nb:0,cos:new Set(),np:0};m[r.rs].nb++;m[r.rs].cos.add(r.ds);if(r.pp)m[r.rs].np++;});
  return Object.values(m).map(r=>({...r,ne:r.cos.size})).sort((a,b)=>b.nb-a.nb);
}

/* KPI */
function renderKPI(){
  const s=stats(FD);
  document.getElementById('k-co').textContent=fmt(s.co.length);
  document.getElementById('k-be').textContent=fmt(s.total);
  document.getElementById('k-av').textContent=s.avg;
  document.getElementById('k-pp').textContent=s.pp.length;
  document.getElementById('k-na').textContent=s.na.length;
  document.getElementById('k-pa').textContent=s.pr.length;
}

/* CHARTS */
const dc=id=>{if(charts[id]){charts[id].destroy();delete charts[id];}};
function renderNat(){
  dc('nat');const cnt={};FD.forEach(r=>{if(r.na)cnt[r.na]=(cnt[r.na]||0)+1;});
  const s=Object.entries(cnt).sort((a,b)=>b[1]-a[1]).slice(0,15);
  charts.nat=new Chart(document.getElementById('ch-nat').getContext('2d'),{type:'bar',data:{labels:s.map(x=>x[0]),datasets:[{data:s.map(x=>x[1]),backgroundColor:CL.g,borderColor:CL.gd,borderWidth:.5,hoverBackgroundColor:CL.yd}]},options:{indexAxis:'y',responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false},tooltip:{callbacks:{label:c=>' '+c.parsed.x+' bén.'}}},scales:{x:{grid:{color:'#f0f0f0'}},y:{ticks:{font:{size:10}}}}}});
}
function renderPie(){
  dc('ppe-c');const pp=FD.filter(r=>r.pp).length;
  charts['ppe-c']=new Chart(document.getElementById('ch-ppe').getContext('2d'),{type:'doughnut',data:{labels:['PPE','Non PPE'],datasets:[{data:[pp,FD.length-pp],backgroundColor:[CL.r,CL.g],borderWidth:2,borderColor:'#fff'}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:'bottom'},tooltip:{callbacks:{label:c=>c.label+': '+c.parsed+' ('+Math.round(100*c.parsed/FD.length)+'%)'}}}}});
}
function renderReg(){
  dc('reg');const d=regS(FD);
  charts.reg=new Chart(document.getElementById('ch-reg').getContext('2d'),{type:'bar',data:{labels:d.map(r=>r.region),datasets:[{label:'Bénéficiaires',data:d.map(r=>r.nb),backgroundColor:CL.g,borderWidth:.5},{label:'Entreprises',data:d.map(r=>r.ne),backgroundColor:CL.y,borderWidth:.5}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:'top',labels:{font:{size:11}}}},scales:{x:{ticks:{font:{size:10}}},y:{grid:{color:'#f0f0f0'}}}}});
}
function renderPct(){
  dc('pct');const bins=Array(20).fill(0);
  FD.forEach(r=>{if(r.pa!==null)bins[Math.min(19,Math.floor(r.pa/5))]++;});
  charts.pct=new Chart(document.getElementById('ch-pct').getContext('2d'),{type:'bar',data:{labels:bins.map((_,i)=>i*5+'%'),datasets:[{data:bins,backgroundColor:CL.y,borderColor:CL.yd,borderWidth:.5}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}},scales:{x:{ticks:{font:{size:9},maxRotation:60}},y:{grid:{color:'#f0f0f0'}}}}});
}
function renderTop(){
  const tb=document.querySelector('#tbl-top tbody');tb.innerHTML='';
  compS(FD).slice(0,30).forEach(c=>{const tr=document.createElement('tr');tr.innerHTML=`<td><strong>${c.ds}</strong></td><td>${c.rs?'<span class="bg">'+c.rs+'</span>':NR}</td><td>${c.gr?'<span class="bgr">'+c.gr+'</span>':NR}</td><td><strong>${c.n}</strong></td><td>${c.avg!==null?c.avg+'%':NR}</td><td>${c.ppe>0?'<span class="br">'+c.ppe+' PPE</span>':'0'}</td>`;tb.appendChild(tr);});
}

/* BASE COMPLÈTE */
function renderDB(){
  const q=dbQ.toLowerCase().trim();
  dbF=FD.filter(r=>!q||[r.ds,r.pn,r.na,r.pr,r.rs,r.gr,r.fp,r.np].some(x=>x&&x.toLowerCase().includes(q)));
  const tot=dbF.length,psz=dbSz>=9999?tot:dbSz,pages=Math.max(1,Math.ceil(tot/psz));
  if(dbPg>pages)dbPg=1;
  const s=(dbPg-1)*psz,e=Math.min(s+psz,tot);
  document.getElementById('db-count-lbl').textContent=fmt(tot)+' enregistrement'+(tot>1?'s':'');
  document.getElementById('db-info').textContent=q?`Filtre "${dbQ}" : ${fmt(tot)} résultat(s) sur ${fmt(FD.length)}`:`${fmt(FD.length)} bénéficiaires dans la sélection — ${fmt(DB.length)} au total`;
  const tb=document.getElementById('db-tbody');tb.innerHTML='';
  dbF.slice(s,e).forEach((r,i)=>{
    const tr=document.createElement('tr');
    tr.innerHTML=`<td style="color:var(--gray);font-size:.74rem;text-align:right">${s+i+1}</td><td><strong>${r.ds||'—'}</strong></td><td>${r.pn||NR}</td><td>${r.rs?'<span class="bg">'+r.rs+'</span>':NR}</td><td>${v(r.na)}</td><td>${v(r.pr)}</td><td style="text-align:center">${vp(r.pa)}</td><td style="text-align:center">${vp(r.pv)}</td><td style="text-align:center">${r.pp?'<span class="br">PPE</span>':''}</td><td>${v(r.fp)}</td><td>${v(r.np)}</td><td>${r.gr?'<span class="bgr">'+r.gr+'</span>':NR}</td><td style="white-space:nowrap;font-size:.79rem">${v(r.da)}</td><td style="text-align:center">${v(r.an)}</td>`;
    tb.appendChild(tr);
  });
  document.getElementById('pg-info').textContent=`Lignes ${fmt(s+1)}–${fmt(e)} sur ${fmt(tot)}`;
  document.getElementById('pg-prev').disabled=dbPg<=1;
  document.getElementById('pg-next').disabled=dbPg>=pages;
  const pg=document.getElementById('pg-pages');pg.innerHTML='';
  let s2=Math.max(1,dbPg-3),e2=Math.min(pages,s2+6);if(e2-s2<6)s2=Math.max(1,e2-6);
  for(let p=s2;p<=e2;p++){const b=document.createElement('button');b.className='pg-btn'+(p===dbPg?' on':'');b.textContent=p;const pp=p;b.onclick=()=>{dbPg=pp;renderDB();};pg.appendChild(b);}
}
function dbNav(d){dbPg+=d;renderDB();}
function dbSzChange(){dbSz=+document.getElementById('pg-sz').value;dbPg=1;renderDB();}
let dbT;
document.getElementById('db-search').addEventListener('input',function(){clearTimeout(dbT);dbQ=this.value;dbT=setTimeout(()=>{dbPg=1;renderDB();},200);});

/* ═══════════════════════════════════════════
   RECHERCHE — SWITCH ONGLETS
═══════════════════════════════════════════ */
function switchSearchTab(tab){
  document.getElementById('stab-co').classList.toggle('active', tab==='co');
  document.getElementById('stab-be').classList.toggle('active', tab==='be');
  document.getElementById('spane-co').style.display = tab==='co' ? 'block' : 'none';
  document.getElementById('spane-be').style.display = tab==='be' ? 'block' : 'none';
  // Vider les résultats et inputs à chaque switch
  if(tab==='co'){ document.getElementById('si').value=''; document.getElementById('sdd').style.display='none'; document.getElementById('ccw').innerHTML=''; }
  if(tab==='be'){ document.getElementById('si-be').value=''; document.getElementById('sdd-be').style.display='none'; document.getElementById('bcw').innerHTML=''; }
}

/* ═══════════════════════════════════════════
   RECHERCHE ENTREPRISE
═══════════════════════════════════════════ */
const allCo=[...new Set(DB.map(r=>r.ds).filter(Boolean))].sort();
const si=document.getElementById('si'),sdd=document.getElementById('sdd');
si.addEventListener('input',function(){
  const q=this.value.trim().toLowerCase();
  sdd.innerHTML='';
  if(!q){sdd.style.display='none';return;}
  const m=allCo.filter(c=>c.toLowerCase().includes(q)).slice(0,35);
  if(!m.length){sdd.style.display='none';return;}
  m.forEach(c=>{
    const rows=DB.filter(r=>r.ds===c);
    const d=document.createElement('div');d.className='ddi';
    const i=c.toLowerCase().indexOf(q);
    d.innerHTML=c.substring(0,i)+'<mark>'+c.substring(i,i+q.length)+'</mark>'+c.substring(i+q.length)
      +`<span class="ddi-meta">${rows.length} bén.</span>`;
    d.addEventListener('click',()=>{si.value=c;sdd.style.display='none';renderCC(c);});
    sdd.appendChild(d);
  });
  sdd.style.display='block';
});

/* ═══════════════════════════════════════════
   RECHERCHE BÉNÉFICIAIRE
═══════════════════════════════════════════ */
const allBe=[...new Set(DB.map(r=>r.pn).filter(Boolean))].sort();
const siBe=document.getElementById('si-be'), sddBe=document.getElementById('sdd-be');

siBe.addEventListener('input',function(){
  const q=this.value.trim().toLowerCase();
  sddBe.innerHTML='';
  if(!q){sddBe.style.display='none';return;}
  const m=allBe.filter(b=>b.toLowerCase().includes(q)).slice(0,35);
  if(!m.length){sddBe.style.display='none';return;}
  m.forEach(b=>{
    // Trouver toutes les entreprises de ce bénéficiaire
    const rowsBe=DB.filter(r=>r.pn===b);
    const isPPE=rowsBe.some(r=>r.pp);
    const d=document.createElement('div');d.className='ddi';
    const i=b.toLowerCase().indexOf(q);
    d.innerHTML=`<span>${b.substring(0,i)}<mark>${b.substring(i,i+q.length)}</mark>${b.substring(i+q.length)}</span>`
      +(isPPE?'<span class="br" style="font-size:.68rem;padding:1px 6px;margin-left:4px">PPE</span>':'')
      +`<span class="ddi-meta">${rowsBe.length} entreprise${rowsBe.length>1?'s':''}</span>`;
    d.addEventListener('click',()=>{siBe.value=b;sddBe.style.display='none';renderBeneficiaire(b);});
    sddBe.appendChild(d);
  });
  sddBe.style.display='block';
});

document.addEventListener('click',e=>{
  if(!e.target.closest('.sw')) {
    sdd.style.display='none';
    sddBe.style.display='none';
  }
});

/* ═══════════════════════════════════════════
   FICHE BÉNÉFICIAIRE
═══════════════════════════════════════════ */
function renderBeneficiaire(nom){
  const rows=DB.filter(r=>r.pn===nom);if(!rows.length)return;
  const isPPE   = rows.some(r=>r.pp);
  const nats    = [...new Set(rows.map(r=>r.na).filter(Boolean))].sort();
  const pays    = [...new Set(rows.map(r=>r.pr).filter(Boolean))].sort();
  const regions = [...new Set(rows.map(r=>r.rs).filter(Boolean))].sort();
  const ppes    = rows.filter(r=>r.pp);
  const pcts    = rows.map(r=>r.pa).filter(x=>x!==null);
  const pcts_v  = rows.map(r=>r.pv).filter(x=>x!==null);
  const avg     = pcts.length  ?(pcts.reduce((a,b)=>a+b,0)/pcts.length).toFixed(1):null;
  const avg_v   = pcts_v.length?(pcts_v.reduce((a,b)=>a+b,0)/pcts_v.length).toFixed(1):null;
  const dates   = rows.map(r=>r.da).filter(Boolean).sort();
  const annees  = [...new Set(rows.map(r=>r.an).filter(Boolean))].sort();
  const sfx     = nom.replace(/[^a-zA-Z0-9]/g,'_').substring(0,30);
  document.getElementById('bcw').innerHTML=`
  <div class="cc">
    <div class="cch"><div class="cci"><i class="fas ${isPPE?'fa-user-shield':'fa-user'}"></i></div>
      <div>
        <div class="ccn">${nom}${isPPE?'<span class="br" style="margin-left:8px;font-size:.72rem">PPE</span>':''}</div>
        <div style="display:flex;gap:5px;flex-wrap:wrap">
          ${regions.map(r=>'<span class="bg">'+r+'</span>').join('')}
          ${nats.map(n=>'<span class="bgr">'+n+'</span>').join('')}
        </div>
      </div>
    </div>
    <div class="ccs">
      <div><span class="csv2">${rows.length}</span><span class="csl">Entreprise${rows.length>1?'s':''}</span></div>
      <div><span class="csv2 ${isPPE?'red':''}">${isPPE?ppes.length:'0'}</span><span class="csl">PPE</span></div>
      <div><span class="csv2">${avg!==null?avg+'%':'—'}</span><span class="csl">Part. moy. action</span></div>
      <div><span class="csv2">${avg_v!==null?avg_v+'%':'—'}</span><span class="csl">Part. moy. voix</span></div>
    </div>
    <div class="ccd">
      <div><div class="cdl"><i class="fas fa-flag"></i> Nationalité(s)</div>${nats.length?nats.join(' • '):NR}</div>
      <div><div class="cdl"><i class="fas fa-globe"></i> Pays de résidence</div>${pays.length?pays.join(' • '):NR}</div>
      <div><div class="cdl"><i class="fas fa-calendar"></i> 1ère déclaration</div>${dates[0]||NR}</div>
      <div><div class="cdl"><i class="fas fa-clock"></i> Dernière MAJ</div>${dates[dates.length-1]||NR}</div>
      <div><div class="cdl"><i class="fas fa-calendar-alt"></i> Année(s)</div>${annees.length?annees.join(', '):NR}</div>
      ${isPPE?'<div><div class="cdl" style="color:var(--r)"><i class="fas fa-user-shield"></i> Fonction(s) PPE</div><div style="color:var(--r);font-weight:600">'+ppes.map(p=>p.fp||p.np||p.ds).filter(Boolean).join(' • ')+'</div></div>':''}
    </div>
  </div>
  <div class="card">
    <div class="ct"><i class="fas fa-building"></i> Entreprises où <strong style="margin:0 3px">${nom}</strong> est bénéficiaire
      <button class="be bxl" style="margin-left:auto" onclick="openExportModal('ben_${sfx}')"><i class="fas fa-file-export"></i> Exporter</button>
    </div>
    <div class="tw"><table><thead><tr>
      <th>Entreprise</th><th>Région</th><th>Greffe</th>
      <th>% Action</th><th>% Voix</th><th>PPE</th><th>Fonction PPE</th><th>Nom PPE</th><th>Date acq.</th>
    </tr></thead><tbody>
    ${rows.map(r=>`<tr>
      <td><strong style="cursor:pointer;color:var(--g);text-decoration:underline dotted"
        onclick="switchSearchTab('co');document.getElementById('si').value='${r.ds.replace(/'/g,"\\'")}';renderCC('${r.ds.replace(/'/g,"\\'")}')">
        ${r.ds}</strong></td>
      <td>${r.rs?'<span class="bg">'+r.rs+'</span>':NR}</td>
      <td>${r.gr?'<span class="bgr">'+r.gr+'</span>':NR}</td>
      <td style="text-align:center">${vp(r.pa)}</td>
      <td style="text-align:center">${vp(r.pv)}</td>
      <td style="text-align:center">${r.pp?'<span class="br">PPE</span>':''}</td>
      <td>${v(r.fp)}</td><td>${v(r.np)}</td>
      <td style="white-space:nowrap">${v(r.da)}</td>
    </tr>`).join('')}
    </tbody></table></div>
  </div>`;
  window._searchRows=rows.map(r=>({'Bénéficiaire':nom,'Entreprise':r.ds,'Région':r.rs||'','Greffe':r.gr||'','Nationalité':r.na||'','Pays résidence':r.pr||'','% Action':r.pa??'','% Voix':r.pv??'','PPE':r.pp?'Oui':'Non','Fonction PPE':r.fp||'','Nom PPE':r.np||'','Date':r.da||'','Année':r.an||''}));
  window._searchSrc='ben_'+sfx;
}

function renderCC(nm){
  const rows=DB.filter(r=>r.ds===nm);if(!rows.length)return;
  const nats=[...new Set(rows.map(r=>r.na).filter(Boolean))].sort();
  const pays=[...new Set(rows.map(r=>r.pr).filter(Boolean))].sort();
  const ppes=rows.filter(r=>r.pp);
  const pcts=rows.map(r=>r.pa).filter(x=>x!==null);
  const avg=pcts.length?(pcts.reduce((a,b)=>a+b,0)/pcts.length).toFixed(1):null;
  const med=pcts.length?pcts.sort((a,b)=>a-b)[Math.floor(pcts.length/2)]:null;
  const dates=rows.map(r=>r.da).filter(Boolean).sort();
  const annees=[...new Set(rows.map(r=>r.an).filter(Boolean))].sort();
  const sfx=nm.replace(/[^a-zA-Z0-9]/g,'_').substring(0,30);
  document.getElementById('ccw').innerHTML=`
  <div class="cc">
    <div class="cch"><div class="cci"><i class="fas fa-building"></i></div>
      <div><div class="ccn">${nm}</div><div style="display:flex;gap:5px;flex-wrap:wrap">
        ${rows[0].rs?'<span class="bg">'+rows[0].rs+'</span>':''}
        ${rows[0].gr?'<span class="bgr">Greffe : '+rows[0].gr+'</span>':''}
      </div></div>
    </div>
    <div class="ccs">
      <div><span class="csv2">${rows.length}</span><span class="csl">Bénéficiaire(s)</span></div>
      <div><span class="csv2 ${ppes.length>0?'red':''}">${ppes.length}</span><span class="csl">PPE</span></div>
      <div><span class="csv2">${avg!==null?avg+'%':'—'}</span><span class="csl">Part. moyenne</span></div>
      <div><span class="csv2">${med!==null?med+'%':'—'}</span><span class="csl">Part. médiane</span></div>
    </div>
    <div class="ccd">
      <div><div class="cdl"><i class="fas fa-flag"></i> Nationalité(s)</div>${nats.length?nats.join(' • '):NR}</div>
      <div><div class="cdl"><i class="fas fa-globe"></i> Pays résidence</div>${pays.length?pays.join(' • '):NR}</div>
      <div><div class="cdl"><i class="fas fa-calendar"></i> 1ère déclaration</div>${dates[0]||NR}</div>
      <div><div class="cdl"><i class="fas fa-clock"></i> Dernière MAJ</div>${dates[dates.length-1]||NR}</div>
      <div><div class="cdl"><i class="fas fa-calendar-alt"></i> Année(s)</div>${annees.length?annees.join(', '):NR}</div>
      ${ppes.length?'<div><div class="cdl" style="color:var(--r)"><i class="fas fa-user-shield"></i> PPE identifiés</div><div style="color:var(--r);font-weight:600">'+ppes.map(p=>p.pn).join(' • ')+'</div></div>':''}
    </div>
  </div>
  <div class="card" style="position:relative">
    <div class="ct"><i class="fas fa-users"></i> Bénéficiaires effectifs
      <button class="be bxl" style="margin-left:auto" onclick="openExportModal('search_${sfx}')"><i class="fas fa-file-export"></i> Exporter</button>
    </div>
    <div class="tw"><table><thead><tr>
      <th>Bénéficiaire</th><th>Nationalité</th><th>Pays résidence</th>
      <th>% Action</th><th>% Voix</th><th>PPE</th><th>Fonction PPE</th><th>Nom PPE</th><th>Date acq.</th>
    </tr></thead><tbody>
    ${rows.map(r=>`<tr><td><strong>${r.pn||'—'}</strong></td><td>${v(r.na)}</td><td>${v(r.pr)}</td><td style="text-align:center">${vp(r.pa)}</td><td style="text-align:center">${vp(r.pv)}</td><td style="text-align:center">${r.pp?'<span class="br">PPE</span>':''}</td><td>${v(r.fp)}</td><td>${v(r.np)}</td><td style="white-space:nowrap">${v(r.da)}</td></tr>`).join('')}
    </tbody></table></div>
  </div>`;
  // Enregistrer la source pour export modal
  window._searchRows=rows;
  window._searchSrc='search_'+sfx;
}

function getExportRows(src){
  if(src&&(src.startsWith('search_')||src.startsWith('ben_'))&&window._searchRows) return window._searchRows;
  if(src==='ppe') return FD.filter(r=>r.pp);
  if(src==='db')  return dbF;
  return compS(FD).slice(0,30);
}

/* PPE */
function getPPEData(){return FD.filter(r=>r.pp).map(r=>({'Bénéficiaire':r.pn,'Entreprise':r.ds,'Région':r.rs||'','Nationalité':r.na||'','Pays résidence':r.pr||'','% Action':r.pa??'','% Voix':r.pv??'','Fonction PPE':r.fp||'','Nom PPE':r.np||''}));}
function renderPPE(){
  const ppes=FD.filter(r=>r.pp);
  const na=[...new Set(ppes.map(r=>r.na).filter(Boolean))];
  const pr=[...new Set(ppes.map(r=>r.pr).filter(Boolean))];
  const pcts=ppes.map(r=>r.pa).filter(x=>x!==null);
  const avg=pcts.length?(pcts.reduce((a,b)=>a+b,0)/pcts.length).toFixed(1):'—';
  const co=[...new Set(ppes.map(r=>r.ds).filter(Boolean))];
  document.getElementById('ppe-kpis').innerHTML=[
    {ico:'fa-user-shield',val:ppes.length,lbl:'Total PPE',col:'var(--r)'},
    {ico:'fa-building',val:co.length,lbl:'Entreprises',col:'var(--yd)'},
    {ico:'fa-flag',val:na.length,lbl:'Nationalités',col:'var(--g)'},
    {ico:'fa-globe',val:pr.length,lbl:'Pays résidence',col:'var(--b)'},
    {ico:'fa-percent',val:avg+'%',lbl:'Part. moy.',col:'var(--gd)'},
  ].map(k=>`<div class="kpi" style="border-top-color:${k.col}"><div class="ki" style="color:${k.col}"><i class="fas ${k.ico}"></i></div><div><div class="kv">${k.val}</div><div class="kl">${k.lbl}</div></div></div>`).join('');
  dc('ppn');dc('ppr');
  const nc={},rc={};ppes.forEach(r=>{if(r.na)nc[r.na]=(nc[r.na]||0)+1;if(r.rs)rc[r.rs]=(rc[r.rs]||0)+1;});
  const ns=Object.entries(nc).sort((a,b)=>b[1]-a[1]);
  const rs2=Object.entries(rc).sort((a,b)=>b[1]-a[1]);
  charts.ppn=new Chart(document.getElementById('ch-pn').getContext('2d'),{type:'bar',data:{labels:ns.map(x=>x[0]),datasets:[{data:ns.map(x=>x[1]),backgroundColor:CL.r,borderWidth:.5}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}},scales:{y:{grid:{color:'#f0f0f0'}}}}});
  charts.ppr=new Chart(document.getElementById('ch-pr').getContext('2d'),{type:'bar',data:{labels:rs2.map(x=>x[0]),datasets:[{data:rs2.map(x=>x[1]),backgroundColor:CL.y,borderColor:CL.yd,borderWidth:.5}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}},scales:{y:{grid:{color:'#f0f0f0'}}}}});
  const tb=document.querySelector('#tbl-ppe tbody');
  tb.innerHTML=ppes.length?ppes.map(r=>`<tr><td><strong style="color:var(--r)">${r.pn||NR}</strong></td><td>${r.ds||NR}</td><td>${r.rs?'<span class="bg">'+r.rs+'</span>':NR}</td><td>${v(r.na)}</td><td>${v(r.pr)}</td><td style="text-align:center">${vp(r.pa)}</td><td style="text-align:center">${vp(r.pv)}</td><td>${v(r.fp)}</td><td>${v(r.np)}</td></tr>`).join('')
    :'<tr><td colspan="9" style="text-align:center;color:var(--gray);padding:18px">Aucun PPE dans la sélection.</td></tr>';
}

/* CARTE */
function initMap(){
  leafMap=L.map('map',{center:[14.4,-14.4],zoom:7,minZoom:6,maxZoom:10,maxBounds:[[12,-17.6],[16.7,-11.3]],maxBoundsViscosity:1.0});
  L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',{attribution:'© OpenStreetMap | © CartoDB | ITIE Sénégal',noWrap:true}).addTo(leafMap);
  updateMap();
  document.querySelectorAll('input[name="mm"]').forEach(r=>r.addEventListener('change',updateMap));
}
function updateMap(){
  if(!leafMap)return;
  leafMap.eachLayer(l=>{if(l instanceof L.CircleMarker)leafMap.removeLayer(l);});
  const metric=document.querySelector('input[name="mm"]:checked').value;
  const rs=regS(FD);const fk={nb:'nb',ne:'ne',np:'np'}[metric];
  const maxV=Math.max(...rs.map(s=>s[fk]||0),1);
  const label={nb:'Bénéficiaires',ne:'Entreprises',np:'PPE'}[metric];
  rs.forEach(s=>{
    const c=COORDS[s.region];if(!c)return;
    const val=s[fk]||0,rad=10+(val/maxV)*45;
    L.circleMarker(c,{radius:rad,fillColor:val?CL.g:'#ccc',fillOpacity:.2+.65*(val/maxV),color:CL.gd,weight:1.5})
     .bindPopup(`<div style="font-family:DM Sans,sans-serif;min-width:190px"><div style="font-size:15px;font-weight:700;color:#1565C0;border-bottom:2px solid #1565C0;padding-bottom:5px;margin-bottom:8px">${s.region}</div><table style="width:100%;font-size:13px"><tr><td>Entreprises</td><td style="text-align:right;font-weight:600">${s.ne}</td></tr><tr><td>Bénéficiaires</td><td style="text-align:right;font-weight:600">${s.nb}</td></tr><tr><td style="color:#D62D20;font-weight:600">PPE</td><td style="text-align:right;color:#D62D20;font-weight:700">${s.np}</td></tr></table></div>`)
     .bindTooltip(`${s.region} — ${label} : ${val}`,{sticky:true}).addTo(leafMap);
  });
  const tb=document.querySelector('#tbl-reg tbody');
  tb.innerHTML=rs.map(s=>`<tr><td><span class="bg">${s.region}</span></td><td>${s.ne}</td><td><strong>${s.nb}</strong></td><td style="${s.np>0?'color:var(--r);font-weight:700':''}">${s.np}</td></tr>`).join('');
}

/* RÉSEAU D3 */
function buildNet(){
  if(typeof d3==='undefined')return;
  const maxC=+document.getElementById('nmx').value;
  const cnt={};FD.forEach(r=>{if(r.ds)cnt[r.ds]=(cnt[r.ds]||0)+1;});
  const top=Object.entries(cnt).sort((a,b)=>b[1]-a[1]).slice(0,maxC).map(e=>e[0]);
  const sub=FD.filter(r=>top.includes(r.ds));
  const nm={};nNodes=[];nLinks=[];
  top.forEach((c,i)=>{const id='C'+i;nm['C|'+c]=id;nNodes.push({id,label:c.length>28?c.substring(0,28)+'…':c,group:'co',full:c});});
  [...new Set(sub.map(r=>r.pn).filter(Boolean))].forEach((b,i)=>{const id='B'+i;nm['B|'+b]=id;nNodes.push({id,label:b.length>24?b.substring(0,24)+'…':b,group:'be',full:b});});
  sub.forEach(r=>{if(!r.ds||!r.pn)return;const s=nm['C|'+r.ds],t=nm['B|'+r.pn];if(s&&t)nLinks.push({source:s,target:t});});
  const sc=document.getElementById('ns-co'),sb=document.getElementById('ns-be');
  sc.innerHTML='<option value="">— Toutes —</option>';sb.innerHTML='<option value="">— Tous —</option>';
  top.forEach(c=>{const o=document.createElement('option');o.value=c;o.textContent=c;sc.appendChild(o);});
  [...new Set(sub.map(r=>r.pn).filter(Boolean))].sort().forEach(b=>{const o=document.createElement('option');o.value=b;o.textContent=b;sb.appendChild(o);});
  drawNet();
}
function drawNet(){
  d3.select('#nsvg').selectAll('*').remove();
  document.getElementById('nib').style.display='none';
  const wrap=document.getElementById('nwrap'),W=wrap.clientWidth||900,H=wrap.clientHeight||500;
  nSvg=d3.select('#nsvg').attr('viewBox',`0 0 ${W} ${H}`);
  const nG=nSvg.append('g');
  nZoom=d3.zoom().scaleExtent([.15,6]).on('zoom',e=>nG.attr('transform',e.transform));
  nSvg.call(nZoom);
  const sim=d3.forceSimulation(nNodes)
    .force('link',d3.forceLink(nLinks).id(d=>d.id).distance(90).strength(.5))
    .force('charge',d3.forceManyBody().strength(-130))
    .force('center',d3.forceCenter(W/2,H/2))
    .force('col',d3.forceCollide(22));
  const link=nG.append('g').selectAll('line').data(nLinks).join('line').attr('stroke','#ddd').attr('stroke-width',1);
  const node=nG.append('g').selectAll('g').data(nNodes).join('g').attr('cursor','pointer')
    .call(d3.drag().on('start',(e,d)=>{if(!e.active)sim.alphaTarget(.3).restart();d.fx=d.x;d.fy=d.y;}).on('drag',(e,d)=>{d.fx=e.x;d.fy=e.y;}).on('end',(e,d)=>{if(!e.active)sim.alphaTarget(0);d.fx=null;d.fy=null;}))
    .on('click',(e,d)=>{e.stopPropagation();zoomNode(d);});
  node.append('circle').attr('r',d=>d.group==='co'?15:9).attr('fill',d=>d.group==='co'?CL.g:CL.y).attr('stroke',d=>d.group==='co'?CL.gd:CL.yd).attr('stroke-width',1.5);
  node.append('text').text(d=>d.label).attr('x',0).attr('y',d=>d.group==='co'?-19:-13).attr('text-anchor','middle').attr('font-size',d=>d.group==='co'?'10px':'9px').attr('fill','#1A1A1A').attr('font-family','DM Sans,sans-serif').attr('font-weight',d=>d.group==='co'?'600':'400');
  sim.on('tick',()=>{link.attr('x1',d=>d.source.x).attr('y1',d=>d.source.y).attr('x2',d=>d.target.x).attr('y2',d=>d.target.y);node.attr('transform',d=>`translate(${d.x},${d.y})`);});
  nSvg.on('click',()=>document.getElementById('nib').style.display='none');
}
function zoomNode(nd){
  if(!nd||!nSvg||!nZoom)return;
  const el=document.getElementById('nsvg'),W=el.clientWidth||900,H=el.clientHeight||500;
  nSvg.transition().duration(700).call(nZoom.transform,d3.zoomIdentity.translate(W/2-2.4*(nd.x||W/2),H/2-2.4*(nd.y||H/2)).scale(2.4));
  const lk=nLinks.filter(l=>(l.source.id||l.source)===nd.id||(l.target.id||l.target)===nd.id);
  const isCo=nd.group==='co';
  const info=document.getElementById('nib');info.style.display='flex';
  info.innerHTML=`<div class="niico" style="background:${isCo?CL.g:CL.yd}"><i class="fas ${isCo?'fa-building':'fa-user'}"></i></div><div><strong style="font-size:14px;display:block">${nd.full}</strong><span style="font-size:12px;color:var(--gray)">${isCo?'Entreprise':'Bénéficiaire'} — ${lk.length} ${isCo?'bénéficiaire(s) relié(s)':'entreprise(s) reliée(s)'}</span></div>`;
}
function focusNode(val,type){
  if(!val)return;
  const nd=nNodes.find(n=>n.full===val&&(type==='co'?n.group==='co':n.group==='be'));
  if(!nd)return;
  if(type==='co')document.getElementById('ns-be').value='';else document.getElementById('ns-co').value='';
  zoomNode(nd);
}

/* EXPORT CSV / JSON */
function dlBlob(blob,name){const u=URL.createObjectURL(blob),a=document.createElement('a');a.href=u;a.download=name;a.click();URL.revokeObjectURL(u);}
function exportCSV(rows,name){
  if(!rows.length)return;
  const h=Object.keys(rows[0]);
  const lines=[h.join(';'),...rows.map(r=>h.map(k=>{const val=r[k]==null?'':String(r[k]);return val.includes(';')||val.includes('"')?'"'+val.replace(/"/g,'""')+'"':val;}).join(';'))];
  dlBlob(new Blob(['\\uFEFF'+lines.join('\\n')],{type:'text/csv;charset=utf-8'}),name+'.csv');
}

/* RENDER ALL */
function renderAll(){
  renderKPI();
  if(typeof Chart!=='undefined'){renderNat();renderPie();renderReg();renderPct();}
  renderTop();
  if(document.getElementById('page-ppe').classList.contains('active'))renderPPE();
  if(document.getElementById('page-database').classList.contains('active'))renderDB();
  if(leafMap)updateMap();
}


/* ═══════════════════════════════════════════
   UX — PASSWORD TOGGLE
═══════════════════════════════════════════ */
function addPwdToggle(inputId){
  const inp=document.getElementById(inputId);
  if(!inp)return;
  const wrap=document.createElement('div');wrap.className='pwd-wrap';
  inp.parentNode.insertBefore(wrap,inp);wrap.appendChild(inp);
  const btn=document.createElement('button');btn.type='button';btn.className='pwd-toggle';
  btn.innerHTML='<i class="fas fa-eye"></i>';
  btn.onclick=()=>{
    const show=inp.type==='password';
    inp.type=show?'text':'password';
    btn.innerHTML=show?'<i class="fas fa-eye-slash"></i>':'<i class="fas fa-eye"></i>';
  };
  wrap.appendChild(btn);
}

/* ═══════════════════════════════════════════
   UX — FILTRES ACTIFS (tags visuels)
═══════════════════════════════════════════ */
function updateActiveTags(){
  const bar=document.getElementById('active-filters-bar');
  if(!bar)return;
  bar.innerHTML='';
  const rs=sv('fr'),na=sv('fn'),pr=sv('fp');
  const gr=document.getElementById('fg').value;
  const pp=document.getElementById('fppe').checked;
  const mn=+document.getElementById('fpmin').value,mx=+document.getElementById('fpmax').value;
  const tags=[];
  if(rs.length) tags.push({lbl:`Région: ${rs.length>1?rs.length+' sélectionnées':rs[0]}`,clear:()=>{[...document.getElementById('fr').options].forEach(o=>o.selected=false);applyF();}});
  if(na.length) tags.push({lbl:`Nationalité: ${na.length>1?na.length+' sél.':na[0]}`,clear:()=>{[...document.getElementById('fn').options].forEach(o=>o.selected=false);applyF();}});
  if(pr.length) tags.push({lbl:`Pays: ${pr.length>1?pr.length+' sél.':pr[0]}`,clear:()=>{[...document.getElementById('fp').options].forEach(o=>o.selected=false);applyF();}});
  if(gr)        tags.push({lbl:`Greffe: ${gr}`,clear:()=>{document.getElementById('fg').value='';applyF();}});
  if(pp)        tags.push({lbl:'PPE uniquement',clear:()=>{document.getElementById('fppe').checked=false;applyF();}});
  if(mn>0||mx<100) tags.push({lbl:`Action: ${mn}%–${mx}%`,clear:()=>{document.getElementById('fpmin').value=0;document.getElementById('fpmax').value=100;document.getElementById('lpmin').textContent='0%';document.getElementById('lpmax').textContent='100%';applyF();}});
  tags.forEach(t=>{
    const el=document.createElement('div');el.className='filter-tag';
    el.innerHTML=`${t.lbl}<button onclick="this.parentElement.remove()" title="Retirer ce filtre">×</button>`;
    el.querySelector('button').addEventListener('click',e=>{e.stopPropagation();t.clear();});
    bar.appendChild(el);
  });
}

/* ═══════════════════════════════════════════
   UX — VALIDATION FORMULAIRES
═══════════════════════════════════════════ */
function validateEmail(e){return /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(e);}

function highlightInvalid(id,msg){
  const el=document.getElementById(id);
  el.style.borderColor='var(--r)';
  el.style.boxShadow='0 0 0 2px rgba(214,45,32,.15)';
  el.focus();
  setTimeout(()=>{el.style.borderColor='';el.style.boxShadow='';},2500);
  showToast(msg,'err','fa-exclamation-circle');
}

/* ═══════════════════════════════════════════
   UX — NOMBRE DE RÉSULTATS DANS SIDEBAR
═══════════════════════════════════════════ */
function updateSidebarCount(){
  const el=document.getElementById('scn');
  if(el){el.style.transition='.3s';el.style.transform='scale(1.15)';setTimeout(()=>el.style.transform='',300);}
}

/* INIT */
// Init robuste : données affichées immédiatement, IndexedDB en parallèle
function initApp(){
  popF();
  applyF();
  buildNet();
  addPwdToggle('admin-pwd');
  updateActiveTags();
}

// Lancer l'app dès que le DOM + scripts sont prêts
if(document.readyState==='loading'){
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  initApp();
}

// IndexedDB en parallèle (n'affecte pas l'affichage)
openIDB().catch(e=>console.warn('IndexedDB non disponible:', e));
"""

    JS_FINAL = JS.replace('__DATA__', data_json)

    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OpenRBE | ITIE Sénégal</title>
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="https://d3js.org/d3.v7.min.js"></script>
<style>{CSS}</style>
</head>
<body>
{BODY}
<script>{JS_FINAL}</script>
</body>
</html>"""

# ══════════════════════════════════════════════════════════
if __name__ == '__main__':
    print("\n" + "="*56)
    print("  OpenRBE v4 — Générateur  |  ITIE Sénégal")
    print("="*56)
    if not os.path.exists(EXCEL_PATH):
        print(f"\n❌  Fichier Excel introuvable : {EXCEL_PATH}")
        sys.exit(1)
    records    = load_data(EXCEL_PATH)
    logo_b64   = encode_logo(LOGO_PATH)
    excel_name = os.path.basename(EXCEL_PATH)
    print(f"\n🔨  Génération de index.html ...")
    html = build_html(records, logo_b64, excel_name)
    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        f.write(html)
    print(f"   ✅  index.html généré ({os.path.getsize(OUT_PATH)//1024} KB)")
    print(f"\n🌐  Ouvrez index.html dans votre navigateur (double-clic)")
    print("\n" + "="*56 + "\n")

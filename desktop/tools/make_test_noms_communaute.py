#!/usr/bin/env python3
# tools/make_test_noms_communaute.py
# Génère data/noms_communaute.json avec N pseudos de test.
import os, json, sys, random

PSEUDO_FRAG_A = ["Léa","Nassim","Zoé","Rayan","Camille","Mélina","Yanis","Noa","Aya","Imran",
                 "Cléo","Isaac","Salomé","Jules","Léna","Anya","Timéo","Nola","Ilan","Maya",
                 "Sohan","Lila","Nolan","Nora","Eliott","Maëlys","Adam","Chloé","Maël","Élise",
                 "Sasha","Inès","Luka","Lison","Nahia","Souleyman","Amine","Tara","Roman","Aaron"]
PSEUDO_FRAG_B = ["M.","B.","D.","K.","T.","V.","R.","L.","S.","C.","Z.","G.","M.","F.","N.","Q.","W.","X.","Y.","H."]

def build_pseudos(n=40):
    out, seen = [], set()
    while len(out) < n and len(seen) < 1000:
        a = random.choice(PSEUDO_FRAG_A)
        b = random.choice(PSEUDO_FRAG_B)
        p = f"{a} {b}"
        key = p.lower()
        if key in seen: 
            continue
        seen.add(key)
        out.append(p)
    return out

def main(argv):
    n = 40
    if len(argv) >= 2:
        try:
            n = max(1, int(argv[1]))
        except Exception:
            pass
    pseudos = build_pseudos(n)
    data = {"pseudos": pseudos}
    # crée le dossier data/ si besoin
    os.makedirs("data", exist_ok=True)
    with open(os.path.join("data", "noms_communaute.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"[OK] Écrit data/noms_communaute.json avec {len(pseudos)} pseudos.")

if __name__ == "__main__":
    main(sys.argv)
# Strategie Scalper V8 - Haute Frequence Challenge

## Vue d'Ensemble

Le Scalper V8 est un Expert Advisor concu pour atteindre les objectifs des challenges prop firms (10%+ mensuel) via une approche de scalping haute frequence. Contrairement aux versions precedentes (V1-V7) qui etaient trop conservatives, cette version privilegie la frequence de trades avec un risk management adaptatif.

### Philosophie

```
Plus de trades + Petit risk par trade + Compounding agressif = 10%+ mensuel
```

| Metrique | V1-V7 | V8 Scalper |
|----------|-------|------------|
| Trades/jour | 2-5 | 8-15 |
| Risk/trade | 1.5% | 0.5-0.8% |
| SL | 25-35 pips | 6-8 pips |
| TP | 25-50 pips | 8-12 pips |
| Hold time | 2-4 heures | 5-20 minutes |
| Sessions | 2-3 | 5 |
| Paires | 1 | 4 |

---

## Types d'Entrees

### 1. MOMENTUM (Principal)

Detection de bougies fortes indiquant une impulsion directionnelle.

**Conditions Long:**
- Bougie haussiere > 40% du range horaire
- RSI entre 45 et 55 (zone de momentum, pas extreme)
- Confirmation sur M5

**Conditions Short:**
- Bougie baissiere > 40% du range horaire
- RSI entre 45 et 55
- Confirmation sur M5

```
Score de base: 3 points
```

### 2. MICRO-BREAKOUT

Cassure du range de l'heure precedente.

**Conditions Long:**
- Close > High(12 bougies) + Buffer ATR
- Cassure confirmee (barre precedente sous le high)

**Conditions Short:**
- Close < Low(12 bougies) - Buffer ATR
- Cassure confirmee

```
Score de base: 3 points
```

### 3. PULLBACK EMA

Retour sur EMA21 dans une tendance etablie.

**Conditions Long:**
- EMA21 > EMA50 (tendance haussiere)
- Low touche EMA21
- Close au-dessus de EMA21

**Conditions Short:**
- EMA21 < EMA50 (tendance baissiere)
- High touche EMA21
- Close en-dessous de EMA21

```
Score de base: 4 points
```

### 4. REVERSAL (Optionnel - Risque)

Retournement aux extremes RSI avec pattern de rejet.

**Conditions Long:**
- RSI < 25 (survendu)
- Pin bar haussier (meche basse > 2x corps)
- Close > Open

**Conditions Short:**
- RSI > 75 (surachete)
- Pin bar baissier (meche haute > 2x corps)
- Close < Open

```
Score de base: 2 points (plus risque)
```

---

## Systeme de Score

Chaque signal recoit un score de base selon son type, puis des bonus:

| Element | Points |
|---------|--------|
| Score type (Momentum/Breakout) | +3 |
| Score type (Pullback) | +4 |
| Score type (Reversal) | +2 |
| EMA alignees avec direction | +1 |
| RSI confirme direction | +1 |

**Score minimum requis:** 3 (ajustable via Mode Turbo)

---

## Gestion des Positions

### Breakeven
- Declenchement: 50% du RR atteint (0.5R)
- SL deplace a Entry + 10% du risk initial

### Partial Close (TP1)
- Declenchement: 100% RR atteint (1:1)
- Action: Fermeture de 50% de la position
- Profit securise: ~4-5 pips sur 50% du lot

### Trailing Stop (TP2)
- Declenchement: Apres TP1
- Distance: ATR * 0.4 (serré pour scalping)
- Objectif: 150% RR sur le reste

### Time Exit
- Declenchement: 20 minutes sans atteindre TP1
- Action: Fermeture si proche de BE (< 30% du SL)
- Evite les trades stagnants

---

## Compounding Agressif

Le systeme ajuste dynamiquement le risk selon les performances:

### Bonus (Wins consecutifs)
```
3 wins -> Risk x 1.25 (+25%)
5 wins -> Risk x 1.50 (+50%)
```

### Malus (Losses consecutifs)
```
2 losses -> Risk x 0.70 (-30%)
3 losses -> Pause 5 minutes, reset
```

### Exemple Pratique
```
Base: 0.6% risk, Balance 100,000$

Win 1: +0.6% = 100,600$
Win 2: +0.6% = 101,204$
Win 3: +0.75% (bonus 25%) = 101,963$
Win 4: +0.75% = 102,728$
Win 5: +0.90% (bonus 50%) = 103,652$

5 trades = +3.65% (vs 3% sans compounding)
```

---

## Mode Turbo

Active automatiquement si en retard sur le challenge (>10% de retard).

### Ajustements Turbo
| Parametre | Normal | Turbo |
|-----------|--------|-------|
| Risk multiplier | x1.0 | x1.3 |
| Max trades/jour | 15 | 20 |
| Score minimum | 3 | 2 |

### Securites Turbo
- Desactivation si Daily DD > 70% du max
- Jamais au-dela des limites DD absolues

---

## Sessions Trading (UTC)

| Session | Heures | Caracteristiques | Max Trades |
|---------|--------|------------------|------------|
| London Open | 07-09 | Volatilite moderee | 2 |
| London Peak | 09-12 | **MEILLEURE** | 4 |
| NY Open | 13-15 | Volatilite haute | 2 |
| NY Peak | 14-17 | **MEILLEURE** | 4 |
| London Close | 15-17 | Overlap | 2 |

**Sessions recommandees:** London Peak + NY Peak = 8 trades potentiels/jour

---

## Multi-Paires

### Configuration par Paire

| Paire | Spread Moy | SL Mult | TP Mult | Max/Jour |
|-------|------------|---------|---------|----------|
| EURUSD | 0.8 pips | x1.0 | x1.0 | 5 |
| GBPUSD | 1.2 pips | x1.2 | x1.2 | 4 |
| USDJPY | 1.0 pips | x1.1 | x1.1 | 4 |
| XAUUSD | 2.5 pips | x2.0 | x2.0 | 3 |

### Exemple EURUSD vs XAUUSD
```
EURUSD: SL = 7 pips, TP = 10 pips
XAUUSD: SL = 14 pips, TP = 20 pips (x2)
```

---

## Parametres par Prop Firm

### FTMO Challenge
```
Risk: 0.6%
Max DD Daily: 4.5%
Max DD Total: 9.0%
Max Trades: 15
Mode: Balanced + Turbo
```

### E8 One Step
```
Risk: 0.5%
Max DD Daily: 4.5%
Max DD Total: 7.5%
Max Trades: 15
Mode: Balanced + Turbo
```

### Funding Pips
```
Risk: 0.4%
Max DD Daily: 3.5%
Max DD Total: 5.5%
Max Trades: 12
Mode: Conservative + Turbo
```

### The5ers
```
Risk: 0.3%
Max DD Daily: 2.5%
Max DD Total: 4.5%
Max Trades: 8
Mode: Conservative (pas de Turbo)
```

---

## Metriques Cibles

### Performance Mensuelle

| Metrique | Minimum | Cible | Optimum |
|----------|---------|-------|---------|
| Trades/mois | 200 | 250 | 300 |
| Win Rate | 52% | 55% | 60% |
| Profit Factor | 1.2 | 1.4 | 1.6 |
| Max DD | <8% | <5% | <3% |
| Profit mensuel | 8% | 12% | 15% |

### Calcul Theorique
```
250 trades/mois
55% WR = 137.5 wins, 112.5 losses
Avg Win: 10 pips, Avg Loss: 7 pips
Net: (137.5 * 10) - (112.5 * 7) = 1375 - 787.5 = 587.5 pips

Avec 0.6% risk et RR 1.4:
Expected monthly: ~12-15%
```

---

## Dashboard V2

L'affichage a ete completement redesigne pour la lisibilite:

### Mode Compact (8 lignes)
```
=== SCALPER V8 | FTMO ===
Progress: 4.2%/10% [========--] 42%
Risk: 0.6% | DD: 1.2%/5%

Session: LONDON PEAK | Trades: 5/15
Last: +8.5p | Streak: W3

Signal: MOMENTUM LONG | Score 4/3
================================
```

### Ameliorations
- ASCII simple (pas de caracteres Unicode)
- Mise a jour toutes les 500ms (pas chaque tick)
- 3 modes: Compact / Standard / Debug
- Information hierarchisee et lisible

---

## Installation

1. Copier `PropFirm_Scalper_v8.mq5` dans `MQL5/Experts/`
2. Copier `Include/Dashboard_v2.mqh` dans `MQL5/Include/` (ou creer le dossier)
3. Compiler l'EA dans MetaEditor
4. Charger le preset correspondant a votre prop firm
5. Attacher l'EA sur un graphique M5 (EURUSD recommande)

---

## Backtesting

### Parametres Recommandes
- Periode: 6-12 mois
- Timeframe: M5
- Modele: Every tick based on real ticks
- Spread: Variable (ou fixe 1.0 pip)

### Validation
- [ ] Win Rate > 52%
- [ ] Profit Factor > 1.2
- [ ] Max DD < 8%
- [ ] Profit mensuel moyen > 8%
- [ ] Pas de mois negatif > -4%

# RCP Tampermonkey Scripts

Kolekcja skryptów Tampermonkey dla systemu RCP (UniWEB) - nowoczesne ulepszenia interfejsu i funkcjonalności.

## 🚀 Skrypty

### 1. **RCPStyle-Piotrek.js** - Podstawowy styl
- **URL**: `https://rcp.novomatic-tech.com/*`
- **Funkcje**:
  - Nowoczesny Material Design
  - Ukrywa niepotrzebne elementy
  - Dodaje Roboto font i Material Icons
  - Responsywny layout

### 2. **RCPHomePage-Enhanced.js** - Strona główna
- **URL**: `https://rcp.novomatic-tech.com/Home.aspx`, `https://rcp.novomatic-tech.com/default.aspx`
- **Funkcje**:
  - ⏰ **Czas wyjścia po 8h**: Dokładna godzina (HH:MM:SS)
  - ⭐ **Czas wyjścia z nadgodzinami**: Wcześniej jeśli masz nadgodziny
  - 📊 **Status balansu**: Nadgodziny (złoty), Do tyłu (czerwony), Na zero (niebieski)
  - 🔄 **Auto-aktualizacja**: Co 5 minut dane, co minutę czasy
  - 📅 **Dni nieobecności**: Licznik nieobecności w miesiącu

### 3. **RCPMojeDane.js** - Analiza czasu pracy
- **URL**: `https://rcp.novomatic-tech.com/Rcp.aspx/MyViewRegistrationsCustomize*`
- **Funkcje**:
  - 🏷️ **Badges nadgodzin**: Każdy dzień pokazuje +/- względem 8h
  - 📊 **Podsumowanie**: Bilans całkowity + dni nieobecności
  - 🔍 **Filtry interaktywne**:
    - Wszystkie dni
    - Tylko nadgodziny  
    - Tylko niedobory
    - Bez weekendów
    - Tylko nieobecności
  - 🎨 **Kolorowe tło**: Zielone dla nadgodzin, czerwone dla niedoborów

## 📥 Instalacja

1. **Zainstaluj Tampermonkey** w przeglądarce:
   - [Chrome/Edge](https://chrome.google.com/webstore/detail/tampermonkey/dhdgffkkebhmkfjojejmpbldmpobfkfo)
   - [Firefox](https://addons.mozilla.org/en-US/firefox/addon/tampermonkey/)

2. **Dodaj skrypty** (w tej kolejności):
   ```
   1. RCPStyle-Piotrek.js      (podstawowy styl - WYMAGANY)
   2. RCPHomePage-Enhanced.js  (strona główna)  
   3. RCPMojeDane.js          (analiza danych)
   ```

3. **Wyłącz** stary skrypt:
   ```
   ❌ RCPMainPage-Piotrek.js  (konflikt z nowym)
   ```

## 🎯 Funkcje

### Strona Główna
```
⭐ Nadgodziny: 2h 3m

┌──────────────┬──────────────┐
│ 15:34:00     │ 13:31:00     │
│ START + 8H   │ Z NADGODZIN. │
└──────────────┴──────────────┘

Dni nieobecności w tym miesiącu: 1
Zaktualizowano: 11:25:20 AM
```

### Moje Dane
- **Filtry**: Szybko znajdź konkretne dni
- **Badges**: `+1h 30m` lub `-45m` przy każdym dniu
- **Kolorowe tło**: Natychmiastowa identyfikacja wzorców

## ⚙️ Konfiguracja

**Norma pracy**: 8h dziennie / 40h tygodniowo (można zmienić w kodzie)

```javascript
const DAILY_HOURS = 8;
const DAILY_SECONDS = DAILY_HOURS * 3600;
```

## 🔧 Rozwój

### Struktura plików
```
tamperMonkey/
├── RCPStyle-Piotrek.js          # Bazowy styl (Piotrek)
├── RCPMainPage-Piotrek.js       # Stary main page (legacy)
├── RCPHomePage-Enhanced.js      # Nowa strona główna
└── RCPMojeDane.js              # Analiza danych
```

### API i selektory
- `#log strong:nth-child(2)` - czas rozpoczęcia pracy
- `table.tabela .tablecell` - wiersze z danymi  
- `.tablesummary` - podsumowanie miesięczne
- Ajax: `/Rcp.aspx/MyViewRegistrationsCustomize` - dane miesięczne

## 🚨 Troubleshooting

**Problem**: Błędne czasy wyjścia
- **Rozwiązanie**: Sprawdź console (F12) - czy `Start time found: XX:XX:XX`

**Problem**: Nie działają filtry  
- **Rozwiązanie**: Upewnij się że `RCPMojeDane.js` jest aktywny na stronie Moje Dane

**Problem**: Brak stylów
- **Rozwiązanie**: `RCPStyle-Piotrek.js` musi być włączony pierwszy

## 📄 Licencja

MIT License - możesz używać i modyfikować według potrzeb.

## 👨‍💻 Autorzy

- **Piotrek** - Bazowe style i architektura
- **Enhanced scripts** - Rozszerzona funkcjonalność

---
*Skrypty są testowane na systemie UniWEB / RCP Novomatic Tech*

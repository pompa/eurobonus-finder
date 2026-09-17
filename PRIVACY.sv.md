<p align="center">
  <img src="docs/icon-256.png" width="96" height="96" alt="EuroBonus Finder-ikon">
</p>

<h1 align="center">Integritetspolicy</h1>

<p align="center"><a href="PRIVACY.md" title="English">🇬🇧</a> &nbsp; <a href="PRIVACY.sv.md" title="Svenska">🇸🇪</a></p>

EuroBonus Finder har inga konton, ingen reklam och ingen analys. Det du surfar
på stannar på din enhet. Den här sidan förklarar exakt vad som händer, för
"vi värnar om din integritet" är ingen förklaring.

*Senast uppdaterad: 17 september 2026.*

## Kortversionen

- Tillägget kontrollerar **på din enhet** om sidan du är på är EuroBonus-partner.
  Den kontrollen lämnar aldrig din iPhone eller iPad.
- Appen gör **en enda** sorts nätverksanrop: den hämtar den publika listan över
  partnerbutiker. Det är samma fil för alla i din marknad och den innehåller
  ingen identifierare för dig.
- Ingenting samlas in, lagras på en server, profileras, säljs eller delas.

## Det som stannar på din enhet

Tillägget sparar några saker i Safaris lokala tilläggslagring:

- **Din marknad** — Sverige, Norge, Danmark eller Finland — så att rätt
  partnerlista laddas.
- **En cachad kopia av partnerlistan**, som uppdateras ungefär en gång i timmen.
- **Vilka engångstips du redan sett**, så att de inte upprepas.

För att se om en sida ger poäng läser tillägget **adressen till sidan du är på**
(domänen och första delen av sökvägen) och, på Googles resultatsidor, länkarna i
resultaten för att kunna märka partnerbutiker. Allt detta sker inuti Safari på
din enhet och jämförs mot den cachade listan. Det skickas aldrig vidare, loggas
aldrig och antecknas ingenstans.

Raderar du appen försvinner allt. Det finns inget annat att rensa.

## Det enda nätverksanropet

Tillägget hämtar partnerlistan från `eb-feed.pompa.se` — en enda statisk
JSON-fil per marknad, identisk för alla användare, hämtad med cookies och
inloggningsuppgifter uttryckligen avstängda. Anropet innehåller **ingen
användaridentifierare, ingen sidadress och ingen information om vad du surfat
på**; det enda det säger är vilken av de fyra marknaderna du valt.

Filen levereras som ett statiskt objekt från Cloudflare R2-lagring placerad
inom **EU**. Det finns ingen applikationsserver bakom och ingen databas. Precis
som vid varje anrop till vilken webbplats som helst ser Cloudflare nödvändigtvis
den anslutande IP-adressen för att kunna leverera filen; den används inte för
att identifiera dig, och ingen profil, logg eller uppgift om dig skapas utifrån
den.

Själva partnerlistan är publik information som SAS publicerar, och som vårt
schemalagda jobb hämtar en gång per natt. Det jobbet går på en timer och ser
aldrig något användaranrop.

## När du går vidare till SAS

Trycker du på **Logga in & tjäna** öppnas SAS egen webbplats i Safari. Från den
stunden är du på en SAS-sida, och
[SAS integritetspolicy](https://www.sas.se/legal/privacy-policy/) gäller för det
som händer där. EuroBonus Finder följer inte efter dig och kan inte se om du
loggade in eller vad du köpte. Vi får aldrig ditt EuroBonus-nummer, ditt
poängsaldo eller dina köp.

## Den här webbplatsen

eurobonus.pompa.se använder [OpenPanel](https://openpanel.dev) för enkel,
aggregerad besöksstatistik — sidvisningar och hänvisande sidor, utan kakor och
utan spårning mellan webbplatser. Webbplatsen kommer också ihåg ditt valda språk
i webbläsarens lokala lagring. Appen och tillägget innehåller inget av detta;
analysen finns bara på webbplatsen du läser nu.

## Barn

EuroBonus Finder är ett shoppingverktyg, riktar sig inte till barn och samlar
medvetet inte in några uppgifter från någon — barn inkluderade.

## Dina rättigheter

Eftersom ingenting om dig någonsin samlas in finns det inget lagrat om dig att
få tillgång till, rätta, exportera eller radera. Raderar du appen försvinner de
uppgifter på enheten som beskrivs ovan.

## Ändringar

Om policyn ändras publiceras den uppdaterade versionen här och datumet högst upp
ändras med den. Historiken för varje ändring är offentlig i
[det här repot](https://github.com/pompa/eurobonus-finder/commits/main/PRIVACY.sv.md).

## Kontakt

Frågor om integritet: **support@pompa.se**, eller
[skapa ett ärende](https://github.com/pompa/eurobonus-finder/issues/new).

EuroBonus Finder är ett oberoende projekt och är inte anslutet till SAS,
EuroBonus eller någon butikspartner — se [DISCLAIMER.md](DISCLAIMER.md).

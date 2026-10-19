# Windows Steam runtime

Validated GodotSteam 4.23.1 runtime, preserved byte-for-byte from the certified Windows staging.
Keep `steamworks/` from this directory beside BasketManager.exe when assembling a Windows Steam distribution.
SteamPurchases.gd loads `steamworks/external.gdextension` lazily; its DLL path is relative to the descriptor.
Do not place these dependencies inside res:// or Web/mobile exports. No certificate, build, key or local server configuration is included.

Windows Desktop uses the `steam` feature. Client purchase/cloud flags remain gated by Windows + steam in code.
Backend routes remain opt-in through STEAM_IDENTITY_ENABLED, STEAM_WALLET_ENABLED and STEAM_PAYMENTS_ENABLED.
STEAM_PAYMENTS_ENVIRONMENT defaults to sandbox; do not set STEAM_PAYMENTS_LIVE_ENABLED=1 for sandbox validation.
Supply STEAM_PUBLISHER_KEY and the existing server JWT configuration externally. Purchase JWTs use the server issuer with /steam-purchases appended and audience steam-purchases; general JWT validation is unchanged.
This integration neither deploys the backend nor exports/publishes a build.

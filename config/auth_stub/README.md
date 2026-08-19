# The stub issuer's keypair

Development and test only, and deliberately checked in: the whole point is that
a fresh clone can mint and verify tokens without a running auth service or a
shared secret. `AUTH_MODE=stub` refuses to boot outside `Rails.env.local?`, so
this key can never sign anything a production noted would accept.

`jwks.json` is the public half, served to nothing — `TokenVerifier` reads it
straight off disk in stub mode instead of fetching auth's JWKS.

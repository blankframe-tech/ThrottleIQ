# Vendored ThrottleIQ code

Exact copies of pure-Dart files from the ThrottleIQ app (`app/lib/…`, same
relative paths, so their relative imports work unchanged). They are the
sensor pipeline and scoring maths the ThrottleIQ app runs and tests (about
2,250 tests in the app).

Don't edit them here. Fix them in `app/lib`, then copy again:

```bash
# from the repo root
for f in $(cd mayabi/lib/src/vendor && find . -name '*.dart'); do cp "app/lib/$f" "mayabi/lib/src/vendor/$f"; done
```

`test/vendor_sync_test.dart` fails while a copy differs from `app/lib`
(skipped when this folder is used outside the ThrottleIQ repo).

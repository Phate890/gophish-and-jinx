# Gophsih and evilginx2

Combination of [evilginx2](https://github.com/kgretzky/evilginx2) and [GoPhish](https://github.com/gophish/gophish) combined with some automation and other resources (thanks twitter).

Close to none of this is mine, I just combine.

## Getting Setup

Assuming you have read the [blog](https://outpost24.com/blog/Better-proxy-than-story) and understand how the setup works, `setup.sh` has been provided to automate the needed configurations for you. Once this script is run and you've fed it the right values, you should be ready to get started. Below is the setup help (note that certificate setup is based on `letsencrypt` filenames):

```
Usage:
./setup <root domain> <evilginx2 subdomain(s)> <gophish subdomain(s)> <redirect url>
 - root domain             - the root domain to be used for the campaign
 - evilginx2 subdomains    - a space separated list of evilginx2 subdomains, can be one if only one
 - gophish subdomains      - a space separated list of gophish subdomains, can be one if only one
 - redirect url            - URL to redirect unauthorized Apache requests
Example:
  ./setup.sh example.com "training login" "download www" https://redirect.com/
```

Redirect rules have been included to keep unwanted visitors from visiting the phishing server as well as an IP blacklist. The blacklist contains IP addresses/blocks owned by ProofPoint, Microsoft, TrendMicro, etc. Redirect rules will redirect known *"bad"* remote hostnames as well as User-Agent strings.

### Ensuring Email Opened Tracking

You **CANNOT** use the default `Add Tracking Image` button when creating your email template. You **MUST** include your own image tag that points at the `GoPhish` server with the tracking URL scheme. This is also explained/shown in the [blog](https://outpost24.com/blog/Better-proxy-than-story).

## Changes To evilginx2

1. All IP whitelisting functionality removed, new proxy session is established for every new visitor that triggers a lure path regardless of remote IP
2. Custom credential logging on submitted passwords to `~/.evilginx/creds.json`
3. Fixed issue with phishlets not extracting credentials from `JSON` requests
4. Further *"bad"* headers have been removed from responses
5. Added logic to check if `mime` type was failed to be retrieved from responses
6. All `X` headers relating to `evilginx2` have been removed throughout the code (to remove IOCs)

## Changes to GoPhish

1. Custom logic inserted into `GetCampaignResults` function that handles `evilginx2` tracking from Apache2 access log
2. Custom logging of events to `JSON` format in `HandleEvent` functions
3. Additional config parameter added for Apache2 log path
4. All `X` headers relating to `GoPhish` have been removed throughout the code (to remove IOCs)
5. Default server name has been changed to `IGNORE`
6. Custom 404 page functionality, place a `.html` file named `404.html` in `templates` folder (example has been provided)
7. `rid=` is now `client_id=` in phishing URLs

## Phishlets Surprise

Included in the `evilginx2/phishlets` folder are three custom phishlets not included in [evilginx2](https://github.com/kgretzky/evilginx2). 

1. `O3652` - modified/updated version of the original `o365` (stolen from [Optiv blog](https://www.optiv.com/insights/source-zero/blog/spear-phishing-modern-platforms))
2. `google` - updated from previous examples online
3. `knowbe4` - custom (don't have access to an account for testing auth URL, works for single-factor campaigns, have not fully tested MFA)

## Limitations 

- All events will only be submitted once into `GoPhish`
- If you do multiple campaigns targeting the same victims without deleting `~/.evilginx/creds.json`, credentials from a previous campaign will take presedence in `GoPhish`

## Credits

GoPhish, Evilginx, fin3ss3g0d
curl --request POST \
  --url https://eapi-gcpstg.broadcom.com/vcf/generateToken \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data client_id=417ecf84-55ae-48c6-bc4b-5d594d60f5a5 \
  --data client_secret=3ef9db45-eb22-42b2-91df-ca0347636619 \
  --data grant_type=client_credentials

# Response:
# {
#   "access_token": "eyJ0eXAiO......",
#   "token_type": "Bearer",
#   "expires_in": 3600,
#   "scope": "oob",
#   "resource": [
#     "https://my.localdomain/*"
#   ]
# }
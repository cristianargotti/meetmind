#!/bin/bash
# Create demo account for Apple reviewer
curl -s -X POST https://api.aurameet.live/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"review@aurameet.live","password":"AuraReview2026!","name":"Apple Reviewer"}' | python3 -m json.tool

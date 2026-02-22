# StoreKit Configuration Notes

Use this shape to avoid `IDEStoreKitEditorConfigurationError`:

1. Put recurring subscriptions under `subscriptionGroups[].subscriptions`.
2. Keep non-consumables/consumables under top-level `products`.
3. Each subscription entry should include:
- `productID`
- `type: "RecurringSubscription"`
- `subscriptionGroupID`
- `groupNumber`
- `recurringSubscriptionPeriod`
4. Intro trial goes in `introductoryOffer` on the subscription entry.
5. Keep `version` as `{ "major": 4, "minor": 0 }`.

Current app IDs:
- Weekly: `com.transfinite.aiassistant.premium.weekly` (3-day free trial)
- Monthly: `com.transfinite.aiassistant.premium.monthly`
- Yearly: `com.transfinite.aiassistant.premium.yearly`
- Lifetime: `com.transfinite.aiassistant.lifetime`
- Subscription group ID: `7E4D282D-E821-4B8B-875B-C01CF95B8EA8`

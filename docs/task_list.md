# Task List

## Objective
Ship the iOS-only (iOS 18+) MVP that ranks and curates photos per the PRD. See @file ../docs/prd.md

## Tasks
- [x] Design integration: switch the results list to match `/docs/design/mockUps`
  - [x] Use SwiftUI `List` with one row per photo (replace `ScrollView`/`LazyVStack`)
  - [x] Leading swipe (swipe right) shows Delete (removes from current results)
  - [x] Trailing swipe (swipe left) shows Share (invokes iOS share sheet)
  - [x] Per-row share uses the original asset when available; fallback to image data
  - [x] Color circle under rank uses hue interpolation Red→Yellow→Green per @file ../docs/design/designInstructions.txt
  - [x] Remove unnecessary header/stats UI; keep progress indicator while processing
  - [x] Visual selection affordance (tap to select/deselect) with trailing checkmark
  - [x] Display fractional 0–5 circle rating with adjacent numeric text
- [ ] Set deployment target to iOS 18.0 in the project settings
- [ ] Add `NSPhotoLibraryUsageDescription` and `NSPhotoLibraryAddUsageDescription` to `bestPictureFinderiOS-Info.plist`
- [ ] Import photos with PHPicker (images only, unlimited selection)
- [ ] Score photos on-device via Vision `CalculateImageAestheticsScoresRequest` (iOS 18+)
- [ ] Sort photos by score (desc) and display list with rank and score
- [ ] Selection: tap to select/deselect; maintain selection state per photo
- [ ] Bulk actions: Select Top 1 / 5 / 10 / 20 (replace current selection)
- [ ] Share Selected: share original assets via share sheet; alert if none selected (use temporary alert instead of toast)
- [ ] Delete Selected: remove selected items from the in-app list only
- [ ] Create Album: name "TO NAME yyyy-MM-dd HH.mm.ss"; if exists, append numeric suffix until unique; add originals in current sorted order
- [ ] Permissions: request `.readWrite`; handle denied/limited states minimally
- [ ] No persistence: remove any stored IDs and do not restore on launch
- [ ] Basic accessibility pass (labels, traits) and on-device QA (iOS 18)

## TODO (deferred per design)
- [ ] Bulk actions: Select All / Select Top 1 / 5 / 10 / 20 (replace selection)
- [ ] Share Selected and Delete Selected actions

## Notes
- Share originals only; no re-encoding/export
- Error toast styling TBD (alert used for now)
- Ties/variety handling out of scope
- All on-device; no backend

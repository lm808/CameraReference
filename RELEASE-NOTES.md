# CameraReference 1.0.14

Accepted and merged to main. Run `release/CameraReference.app`; bridge remains **0.5.3**. Existing settings, identities and minimise behaviour are unchanged.

**Preview captured Lightroom window…** now shows the raw frame before geometry validation or normalization. Padding and displacement remain visible for diagnosis even when placement would reject the frame. Movement checks no longer discard acquired preview images. Overlay placement and calibration snapping retain their safeguards.

Actual capture/permission/conversion errors still report an error when no image is available. Preview captures afresh; it does not retain an earlier failed attempt. No image is saved automatically. Off-screen reliability is not declared fixed. See TESTING.md for a short check during normal use. No DMG has been packaged.

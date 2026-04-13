# Image Similarity Search

iOS demo app for real-time camera frame processing and AI-driven product filtering.  
The app streams camera frames, classifies/labels the current frame, and continuously refines product results based on model output.

## Realtime Camera + AI Pipeline

- **Realtime frame ingest**: camera frames are captured continuously from AVFoundation stream.
- **Model output pipeline**: each valid frame is passed through the AI labeling flow and emits normalized output.
- **Realtime product filtering**: model output is mapped to product fields (`title`/`description`) and result list is updated live.
- **Non-blocking UI**: reactive pipeline (RxSwift) keeps inference and filtering off the main rendering path.
- **Data source**: products are loaded from [Fake Store API](https://fakestoreapi.com/products) and displayed with progressive image loading.

## Demo

<p align="center">
  <img src="Image%20Similary%20Search/Resources/ImageSimilaritySearch.gif" width="340" alt="Realtime camera-to-product filtering demo" />
</p>

## Technology Contributions & Product-Level Practicality

- **On-device AI integration**: practical pattern for real-time visual intelligence in consumer/product apps.
- **Reactive orchestration**: stable event pipeline for camera stream, model inference, and UI update coordination.
- **Search relevance loop**: converts model output into product-level ranking/filtering for shopping/discovery scenarios.
- **Core Data extensibility**: `CatalogProduct` model supports persistent catalog metadata and optional feature vectors.
- **Scalable architecture direction**: suitable baseline for retail assistant, visual search, content moderation, and smart catalog experiences.

## Permissions

- **Camera**: required for realtime frame capture.
- **Photo Library**: used when saving or selecting images.
- **Local Network**: only needed for local/backend environments (if enabled).

All permission descriptions are configured in `Info.plist`.

## Contributing

Contributions are welcome via pull requests and issue discussions.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).

---
Initial contribution: 2025-09-30  
Latest contribution update: 2026-04-14


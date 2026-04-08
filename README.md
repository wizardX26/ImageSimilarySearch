# AI Integration Sample

A sample iOS application demonstrating AI-powered image similarity search, product recognition, and vector embedding using Core ML models and Core Data. Built with Swift, RxSwift, and UIKit.

## Features

- **Camera Integration**: Capture images directly from the app.
- **Image Similarity Search**: Find products similar to a captured or selected image using AI models.
- **Product Recognition**: Identify products using Core ML models (MobileNetV2, ResNet50).
- **Vector Embedding**: Store and search product feature vectors in Core Data.
- **Reactive Programming**: Utilizes RxSwift for responsive UI and data flow.
- **Modern UI**: Built with Storyboards and custom views.

## Project Structure

```
AI integration sample/
├── model.swift                # Product and ProductList data models
├── ViewController.swift       # Main UI logic and bindings
├── ViewModel.swift            # ProductViewModel with RxSwift
├── Delegate/                  # AppDelegate and SceneDelegate
├── Resources/
│   ├── Info.plist             # App configuration and permissions
│   ├── MobileNetV2.mlmodel    # Core ML model for image recognition
│   ├── Resnet50.mlmodel       # Core ML model for image recognition
│   ├── ProductItem.xcdatamodeld/ # Core Data model for products
│   └── Assets.xcassets/       # App icons and colors
├── Sources/
│   ├── Camera & Image Similarity/
│   │   ├── CameraViewController.swift
│   │   ├── CameraGestureHandler.swift
│   │   ├── ImageProcesssing/
│   │   │   ├── ImageSimilarityService.swift
│   │   │   ├── AILabelServiceType.swift
│   │   │   └── AIVectorServiceType.swift
│   │   └── ImageViewModel/
│   │       ├── ImageLabelViewModel.swift
│   │       └── imageVMStructruebyChatGPT.swift
│   ├── Extensions/
│   │   ├── RxSwift_Extension.swift
│   │   └── UIImage+PixelBuffer.swift
│   ├── networking/
│   │   ├── endpoints.swift
│   │   └── serview layer.swift
│   ├── VectorEmbedding/
│   │   ├── ProductCoreDataService.swift
│   │   └── ProductItem.swift
│   └── view/
│       ├── ActivityIndicator.swift
│       ├── CollectionViewCell.swift
│       └── CollectionViewCell.xib
└── Base.lproj/
    ├── Main.storyboard        # Main UI storyboard
    └── LaunchScreen.storyboard
```

## Core Technologies

- **Swift 5**
- **UIKit**
- **RxSwift / RxCocoa**
- **Moya**
- **Core ML** (MobileNetV2, ResNet50)
- **Core Data**
- **AVFoundation** (Camera)
- **Kingfisher** (Image loading/caching)

- **Swift Package Management**

## Getting Started

1. **Clone the repository**  
   `git clone <repo-url>`

2. **Open in Xcode**  
   Open `AI integration sample.xcodeproj` in Xcode.

3. **Install dependencies**  
   - Ensure CocoaPods or Swift Package Manager is set up for Moya, RxSwift, RxCocoa, and Kingfisher.
   - Add any missing pods/packages if needed.
   - pod install

4. **Build and Run**  
   - Select a simulator or device.
   - Press `Cmd+R` to build and run.

## Permissions

- **Camera**: Required for capturing images.
- **Photo Library**: Required for saving and selecting images.
- **Local Network**: For backend connectivity (if applicable).

All permissions are described in `Info.plist`.

## Data Model

- **ProductItem**: Stores product details and feature vectors for similarity search.
- **Core Data**: Used for persistent storage of products and vectors.

## AI Models

- **MobileNetV2.mlmodel**
- **Resnet50.mlmodel**

These models are used for image classification and feature extraction.

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License

[personal project]
Story
- An app create for complete 6 months Intership at where I choose - BiPlus Software Solution JSC.
- These whole job would be done within 2 days and a night (09/27 - 09/28) with a software engineer, cover a range of problems invole iOS's app capacity, peformance & user experience, which can list downthere:
    + CoreML model integration on device: light & fast prio
    + Reactive programming to solve task timing & real time Camera's session frame
    + Handle data flow to not block UI main thread
    + Camera's orientation to choose the right shape at Camera's frame -> imageView
    + Solution to Image Similary Search
    + Data caching to search 
    
- Issue will be up to date in future:
    * Swift
    [] collectionView prefetch & pagination
    [] Natural gesture
    [] viewModel init before viewDidLoad
    [] Speed of collectionView show data/cache/image similary search
    [] Arthorihm to fetch data in Arrays, CoreData -> optimize <NSFetchedResultsController>
    [] Moya/RxSwift
    
    * AI model
    [] Custom model
    [] Model Thread processing: CPU? GPU? CPU & Neutral Engine
    [] RxSwift: syntax & organization
    [] 
    
    * Coding style & convention
    [] .self
    [] naming convention
    [] 
    
    * Camera hanđle
    [] UIImagePickerController
    [] AVFoundation
    []
    
    * Language
    [] OOP
    [] POP
    [] custom UI components/ package/ .xc
    [] MVVM
    [] 


------------------------------------------------------------------------------------
Initial - 09/30/2025
Update history
- 09/30/2025


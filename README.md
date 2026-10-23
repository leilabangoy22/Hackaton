<h1 align="center">
	<img width="500" src="Backend/LOGO_LalayAndFriends.png" alt="KCORD">
	<br>
</h1>

# Hackaton

A multi-tier software project containing a Flutter application frontend, Backend API service, and utility Scripts [31].

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#project-layout">Project Layout</a></li>
    <li><a href="#built-with">Built With</a></li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#running-the-tests">Running the Tests</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

This Web Application hosts an AI that predicts flood risk based on geographical location and environmental data. It uses a grid-based system to identify nearby areas and assess their potential flood risk.

The application integrates environmental information, including saved elevation data, current weather conditions, and nearby mapped lakes and reservoirs, to support flood risk assessment.

By combining geographical data and AI-powered analysis, the system aims to provide users with information about potential flooding in their selected locations and help them make informed decisions.

---

<!-- PROJECT LAYOUT -->
## Project Layout

```
.
├── Backend/        # Backend API service and business logic
├── Flutter/        # Flutter client application
├── Scripts/        # Helper scripts and operational utilities
└── .gitignore      # Git ignore rules
```

---

<!-- BUILT WITH -->
## Built With

* [Flutter](https://flutter.dev/)
* [Dart](https://dart.dev/)
* Backend API Services
* Shell / Automation Scripts

---

<!-- GETTING STARTED -->
## Getting Started

Follow these steps to set up the project locally.

### Prerequisites

* **Flutter SDK**
* **Backend Runtime** (e.g. Node.js / Python)
* **Git**

### Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/leilabangoy22/Hackaton.git
   cd Hackaton
   ```

2. **Set up the Backend:**
   ```sh
   cd Backend
   # Install dependencies and setup environment variables
   ```

3. **Set up the Flutter frontend:**
   ```sh
   cd ../Flutter
   flutter pub get
   ```

4. **Review helper scripts:**
   ```sh
   cd ../Scripts
   # Run local automation scripts as needed
   ```

---

<!-- USAGE -->
## Usage

### Running the Backend Service
```sh
cd Backend
# Start backend service
```

### Running the Flutter Frontend
```sh
cd Flutter
flutter run
```

---

<!-- RUNNING THE TESTS -->
## Running the Tests

* **Frontend Tests:**
  ```sh
  cd Flutter
  flutter test
  ```

* **Backend Tests:**
  ```sh
  cd Backend
  # Run backend unit and integration test suite
  ```

---

<!-- ROADMAP -->
## Roadmap

- [x] Initial repository structure (`Backend/`, `Flutter/`, `Scripts/`) [31]
- [ ] Develop Backend API endpoints
- [ ] Connect Flutter frontend with Backend API
- [ ] Automated testing and continuous integration
- [ ] Expand utility scripts and release workflow

---

<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m "Add some AmazingFeature"`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

<!-- LICENSE -->
## License

Distributed under the MIT License (MIL). See `LICENSE` for more information.

---

<!-- CONTACT -->
## Contact

Project Link: [https://github.com/leilabangoy22/Hackaton](https://github.com/leilabangoy22/Hackaton)

---

<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [Best-README-Template](https://github.com/othneildrew/Best-README-Template)
* [Flutter Documentation](https://docs.flutter.dev/)

let map;
let selectedLocation;
let selectedMarker;
let searchBox;
let searchResults = [];

function initMap(initialLat, initialLng) {
  map = new google.maps.Map(document.getElementById("map"), {
    center: { lat: initialLat, lng: initialLng },
    zoom: 12,
    mapTypeId: 'roadmap'
  });

  // Event listener for map click to select location
  map.addListener('click', (mapsMouseEvent) => {
    setSelectedLocation(mapsMouseEvent.latLng);
  });

  // Initialize search box
  const input = document.getElementById("search-input");
  searchBox = new google.maps.places.SearchBox(input);
  map.controls[google.maps.ControlPosition.TOP_LEFT].push(input);

  // Bias the SearchBox results towards current viewport
  map.addListener('bounds_changed', () => {
    searchBox.setBounds(map.getBounds());
  });

  // Listen for the user selecting a place from the search results
  searchBox.addListener('places_changed', () => {
    const places = searchBox.getPlaces();

    if (places.length == 0) {
      return;
    }

    // For each place, get the icon, name and location.
    const bounds = new google.maps.LatLngBounds();
    places.forEach((place) => {
      if (!place.geometry || !place.geometry.location) {
        console.log("Returned place contains no geometry");
        return;
      }

      setSelectedLocation(place.geometry.location);

      if (place.geometry.viewport) {
        bounds.union(place.geometry.viewport);
      } else {
        bounds.extend(place.geometry.location);
      }
    });
    map.fitBounds(bounds);
  });

  // Set initial location if provided
  if (initialLat && initialLng) {
    setSelectedLocation({ lat: initialLat, lng: initialLng });
  }
}

function setSelectedLocation(latLng) {
  selectedLocation = latLng;
  updateMarker(latLng);
  displaySelectedLocation();
  // You would typically call a function here to pass the selectedLocation
  // back to your application logic (similar to onLocationSelected in Flutter)
  console.log("Selected Location:", selectedLocation.lat(), selectedLocation.lng());
}

function updateMarker(latLng) {
  if (selectedMarker) {
    selectedMarker.setPosition(latLng);
  } else {
    selectedMarker = new google.maps.Marker({
      position: latLng,
      map: map,
      draggable: true,
      title: "Selected Location",
    });

    // Event listener for marker drag end
    selectedMarker.addListener('dragend', (event) => {
      setSelectedLocation(event.latLng);
    });
  }
}

function displaySelectedLocation() {
  const locationDisplay = document.getElementById("selected-location");
  if (locationDisplay) {
    locationDisplay.textContent = `Selected Location: ${selectedLocation.lat().toFixed(6)}, ${selectedLocation.lng().toFixed(6)}`;
  }
}
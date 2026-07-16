# Run the unit tests with the race detector and code coverage enabled

if (!(Test-Path env:SKILLSGO_HUB_ENVIRONMENT)) {$env:SKILLSGO_HUB_ENVIRONMENT = "test"}

if (!(Test-Path env:SKILLSGO_HUB_MINIO_ENDPOINT)) {
    $env:SKILLSGO_HUB_MINIO_ENDPOINT = "http://127.0.0.1:9001"
}

if (!(Test-Path env:SKILLSGO_HUB_MONGO_STORAGE_URL)) {
    $env:SKILLSGO_HUB_MONGO_STORAGE_URL = "mongodb://127.0.0.1:27017"
}
$env:GO111MODULE="on"
& go test -mod=vendor -race -coverprofile cover.out -covermode atomic ./...

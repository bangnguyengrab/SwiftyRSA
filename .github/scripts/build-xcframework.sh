#!/usr/bin/env bash

# Build SwiftyRSA XCFramework with Library Evolution enabled
# Adapted for GitHub Actions CI - no cloning needed, uses checked-out code
# METHOD: Brute-force text replacement (The "Nuclear Option")
# This is required because the compiler flag failed to fix _objc_ types.
#
# Usage: ./build-xcframework.sh <version>
# Example: ./build-xcframework.sh 1.8.0
#
# Environment Variables:
#   FRAMEWORK_NAME: Name of the framework (default: SwiftyRSA)
#   SCHEME_NAME: Xcode scheme name (default: "SwiftyRSA iOS")

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Cleanup function for temporary directories
cleanup() {
    local exit_code=$?
    if [ -n "${TEMP_DIRS:-}" ]; then
        echo "Cleaning up temporary directories..."
        for temp_dir in $TEMP_DIRS; do
            [ -d "$temp_dir" ] && rm -rf "$temp_dir" || true
        done
    fi
    exit $exit_code
}

# Register cleanup trap
trap cleanup EXIT INT TERM

# Get version from argument (passed from GitHub Actions)
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Error: Version argument is required"
    echo "Usage: $0 <version>"
    exit 1
fi

FRAMEWORK_NAME="${FRAMEWORK_NAME:-SwiftyRSA}"
SCHEME_NAME="${SCHEME_NAME:-SwiftyRSA iOS}"

# Use current directory (already checked out in CI)
REPO_DIR="$(pwd)"
BUILD_DIR="${REPO_DIR}/build"
OUTPUT_DIR="${BUILD_DIR}/${FRAMEWORK_NAME}"
PROJECT_FILE="${REPO_DIR}/${FRAMEWORK_NAME}.xcodeproj"

# Track temporary directories for cleanup
TEMP_DIRS=""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Building ${FRAMEWORK_NAME} XCFramework (Version: ${VERSION})${NC}"
echo "=================================================="
echo "Repository: ${REPO_DIR}"
echo "Output: ${OUTPUT_DIR}"
echo "=================================================="

# Verify prerequisites
echo -e "${BLUE}🔍 Verifying prerequisites...${NC}"

# Check if Xcode project exists
if [ ! -d "$PROJECT_FILE" ]; then
    echo -e "${RED}❌ Error: Xcode project not found at ${PROJECT_FILE}${NC}"
    exit 1
fi

# Check if required tools are available
command -v xcodebuild >/dev/null 2>&1 || { echo -e "${RED}❌ Error: xcodebuild is not installed${NC}"; exit 1; }
command -v xcrun >/dev/null 2>&1 || { echo -e "${RED}❌ Error: xcrun is not installed${NC}"; exit 1; }
command -v swift >/dev/null 2>&1 || { echo -e "${RED}❌ Error: swift is not installed${NC}"; exit 1; }
command -v zip >/dev/null 2>&1 || { echo -e "${RED}❌ Error: zip is not installed${NC}"; exit 1; }

# Verify Xcode version
XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo "Using: $XCODE_VERSION"

# Clean output directory
echo -e "${BLUE}🧹 Cleaning output directory...${NC}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Build Settings
BUILD_LIBRARY_FOR_DISTRIBUTION="YES"
OTHER_SWIFT_FLAGS="-Xfrontend -enable-library-evolution"

# --- THE FIX FUNCTION ---
# We manually strip 'SwiftyRSA.' from the interface files.
# Note: sed -i '' is macOS-specific (works on GitHub Actions macOS runners)
sanitize_interface() {
    local archive_path=$1
    echo -e "${BLUE}🔧 Sanitizing .swiftinterface in ${archive_path}...${NC}"
    
    # Find all .swiftinterface files in the archive
    local interface_count=0
    while IFS= read -r interface_file; do
        if [ -f "$interface_file" ]; then
            interface_count=$((interface_count + 1))
            
            # 1. Fix Public Swift Types (The ones that worked before)
            sed -i '' 's/SwiftyRSA\.Message/Message/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.Key/Key/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.PublicKey/PublicKey/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.PrivateKey/PrivateKey/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.EncryptedMessage/EncryptedMessage/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.ClearMessage/ClearMessage/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.Signature/Signature/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.VerificationResult/VerificationResult/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.Padding/Padding/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\.SwiftyRSAError/SwiftyRSAError/g' "$interface_file"
            
            # 2. Fix Internal ObjC Types (The ones failing in your log)
            # We explicitly replace 'SwiftyRSA._objc_X' with just '_objc_X'
            sed -i '' 's/SwiftyRSA\._objc_PrivateKey/_objc_PrivateKey/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\._objc_PublicKey/_objc_PublicKey/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\._objc_KeyPair/_objc_KeyPair/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\._objc_EncryptedMessage/_objc_EncryptedMessage/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\._objc_ClearMessage/_objc_ClearMessage/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\._objc_Signature/_objc_Signature/g' "$interface_file"
            sed -i '' 's/SwiftyRSA\._objc_VerificationResult/_objc_VerificationResult/g' "$interface_file"
        fi
    done < <(find "${archive_path}" -name "*.swiftinterface" 2>/dev/null || true)
    
    if [ "$interface_count" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Warning: No .swiftinterface files found to sanitize${NC}"
    else
        echo -e "${GREEN}✅ Sanitized ${interface_count} .swiftinterface file(s)${NC}"
    fi
}

build_framework() {
    local platform=$1
    local destination=$2
    local scheme_name="${SCHEME_NAME}"
    local derived_data=$(mktemp -d)
    
    # Track for cleanup on error
    TEMP_DIRS="${TEMP_DIRS} ${derived_data}"
    
    echo -e "${GREEN}🔨 Building for ${platform}...${NC}"
    echo "Destination: ${destination}"
    echo "Scheme: ${scheme_name}"
    echo "Derived Data: ${derived_data}"
    
    # Archive
    if ! xcrun xcodebuild archive \
        -project "${PROJECT_FILE}" \
        -scheme "${scheme_name}" \
        -configuration Release \
        -destination "${destination}" \
        -archivePath "${derived_data}/${platform}.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION="${BUILD_LIBRARY_FOR_DISTRIBUTION}" \
        "OTHER_SWIFT_FLAGS=${OTHER_SWIFT_FLAGS}" \
        -quiet; then
        echo -e "${RED}❌ Archive failed for ${platform}${NC}"
        rm -rf "${derived_data}"
        exit 1
    fi
    
    # Apply the Patch immediately after building
    sanitize_interface "${derived_data}/${platform}.xcarchive"
    
    # Export Framework
    local framework_path="${derived_data}/${platform}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework"
    if [ -d "$framework_path" ]; then
        mkdir -p "${OUTPUT_DIR}/${platform}"
        cp -R "$framework_path" "${OUTPUT_DIR}/${platform}/"
        echo -e "${GREEN}✅ Successfully built ${platform}${NC}"
    else
        echo -e "${RED}❌ Build failed for ${platform}${NC}"
        echo "Expected framework at: ${framework_path}"
        echo "Archive contents:"
        ls -la "${derived_data}/${platform}.xcarchive/Products/Library/Frameworks/" || true
        rm -rf "${derived_data}"
        exit 1
    fi
    
    # Cleanup successful build (trap handles failures)
    rm -rf "${derived_data}"
    # Remove from cleanup list since we cleaned it up
    TEMP_DIRS=$(echo "$TEMP_DIRS" | sed "s|${derived_data}||" | tr -s ' ')
}

# 1. Build iOS Device
build_framework "ios-arm64" "generic/platform=iOS"

# 2. Build Simulator
build_framework "ios-arm64_x86_64-simulator" "generic/platform=iOS Simulator"

# 3. Create XCFramework
echo -e "${BLUE}📦 Creating XCFramework...${NC}"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"

if ! xcrun xcodebuild -create-xcframework \
    -framework "${OUTPUT_DIR}/ios-arm64/${FRAMEWORK_NAME}.framework" \
    -framework "${OUTPUT_DIR}/ios-arm64_x86_64-simulator/${FRAMEWORK_NAME}.framework" \
    -output "${XCFRAMEWORK_PATH}"; then
    echo -e "${RED}❌ Failed to create XCFramework${NC}"
    exit 1
fi

# Verify XCFramework was created
if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo -e "${RED}❌ Error: XCFramework was not created at ${XCFRAMEWORK_PATH}${NC}"
    exit 1
fi

# Validate XCFramework structure
echo -e "${BLUE}🔍 Validating XCFramework structure...${NC}"
if [ ! -f "${XCFRAMEWORK_PATH}/Info.plist" ]; then
    echo -e "${RED}❌ Error: XCFramework Info.plist not found${NC}"
    exit 1
fi

# Check that we have at least one platform slice
# XCFramework structure: SwiftyRSA.xcframework/ios-arm64/SwiftyRSA.framework
# So we look for .framework directories inside platform directories
PLATFORM_COUNT=$(find "${XCFRAMEWORK_PATH}" -mindepth 2 -maxdepth 2 -type d -name "*.framework" | wc -l | tr -d ' ')
if [ "$PLATFORM_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ Error: XCFramework contains no platform slices${NC}"
    echo "XCFramework structure:"
    ls -la "${XCFRAMEWORK_PATH}" || true
    exit 1
fi
echo -e "${GREEN}✅ XCFramework structure validated (${PLATFORM_COUNT} platform slice(s))${NC}"

# 4. Zip & Checksum
echo -e "${BLUE}📦 Creating zip archive...${NC}"
cd "${OUTPUT_DIR}"
ZIP_FILE="${FRAMEWORK_NAME}.xcframework.zip"

if ! zip -r "${ZIP_FILE}" "${FRAMEWORK_NAME}.xcframework" -q; then
    echo -e "${RED}❌ Failed to create zip file${NC}"
    exit 1
fi

# Verify zip was created
if [ ! -f "$ZIP_FILE" ]; then
    echo -e "${RED}❌ Error: Zip file was not created${NC}"
    exit 1
fi

# Compute checksum
echo -e "${BLUE}🔐 Computing checksum...${NC}"
if ! CHECKSUM=$(swift package compute-checksum "${ZIP_FILE}"); then
    echo -e "${RED}❌ Failed to compute checksum${NC}"
    exit 1
fi

echo "=================================================="
echo -e "${GREEN}✅ SUCCESS!${NC}"
echo "Version: ${VERSION}"
echo "XCFramework: ${XCFRAMEWORK_PATH}"
echo "Zip: ${OUTPUT_DIR}/${ZIP_FILE}"
echo "Checksum: ${CHECKSUM}"
echo "=================================================="

# Save checksum to file for GitHub Actions
echo "${CHECKSUM}" > "${OUTPUT_DIR}/checksum.txt"

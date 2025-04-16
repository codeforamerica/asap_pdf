# Name of the Docker image to create for CI operations
LOCAL_CI_IMAGE='asap_pdf:ci'

# Get the absolute path to the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Construct the base Docker run command with volume mounting
# This mounts the parent directory of the script (project root) to /workspace in the container
BASE_COMMAND="docker run --rm -v $SCRIPT_DIR/../../:/workspace $LOCAL_CI_IMAGE"

# Build the Docker image using the Dockerfile in the parent directory
# The -t flag tags the image with the name specified in LOCAL_CI_IMAGE
docker build -t $LOCAL_CI_IMAGE $SCRIPT_DIR/../.

# Print the base Docker command for debugging purposes
echo "$BASE_COMMAND"

# Run isort to sort Python imports
echo "Output from isort utility..."
$BASE_COMMAND isort --profile black python_components/.
echo "\n"

# Run black to format Python code according to PEP 8 standards
echo "Output from black utility..."
$BASE_COMMAND black python_components/.
echo "\n"

# Run flake8 to check for style guide enforcement and lint errors
echo "Output from flake8 utility..."
$BASE_COMMAND flake8 --ignore=E501 python_components/.
echo "\n"
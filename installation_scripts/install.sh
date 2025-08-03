#!/bin/bash
set -e

# Function to handle errors
handle_error() {
    echo "ERROR: Command failed at line $1"
    echo "Last command: $2"
    echo "Exit code: $3"
    exit 1
}

# Set error trap
trap 'handle_error $LINENO "$BASH_COMMAND" $?' ERR

echo "Starting OpenDrop installation..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "WARNING: Running as root. This script should be run as a regular user with sudo privileges."
   read -p "Continue anyway? (y/N): " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

# Add deadsnakes PPA and update package list
echo "Adding deadsnakes PPA and updating package list..."
sudo add-apt-repository ppa:deadsnakes/ppa -y || {
    echo "ERROR: Failed to add deadsnakes PPA. Checking if it already exists..."
    grep -q "deadsnakes" /etc/apt/sources.list.d/* && echo "PPA already exists, continuing..." || exit 1
}
sudo apt update || {
    echo "ERROR: Failed to update package list"
    exit 1
}

# Install Python 3.11 and development headers
echo "Installing Python 3.11 and development headers..."
sudo apt install -y python3.11-full python3.11-distutils libpython3.11-dev || {
    echo "ERROR: Failed to install Python 3.11"
    exit 1
}
sudo apt install -y libboost-dev libboost-test-dev
wget https://bootstrap.pypa.io/get-pip.py
python3.11 get-pip.py
# Verify Python 3.11 installation
python3.11 --version || {
    echo "ERROR: Python 3.11 installation failed"
    exit 1
}
echo "Python 3.11 installed successfully: $(python3.11 --version)"

# Install OpenMPI
echo "Installing OpenMPI..."
sudo apt install -y openmpi-bin libopenmpi-dev || {
    echo "ERROR: Failed to install OpenMPI"
    exit 1
}

# Verify MPI installation
which mpicc && which mpicxx || {
    echo "ERROR: MPI compilers not found after installation"
    exit 1
}
echo "MPI installed successfully: $(mpicc --version | head -n 1)"

# Install system dependencies required by OpenDrop
echo "Installing system dependencies..."
sudo apt install -y \
  libglib2.0-dev \
  libcairo2-dev \
  libgirepository1.0-dev \
  libusb-1.0-0-dev \
  libgtk-3-dev \
  gir1.2-gtk-3.0 \
  build-essential \
  cmake \
  pkg-config \
  libatlas-base-dev \
  libcanberra-gtk-module \
  libcanberra-gtk3-module \
  unzip \
  wget \
  git || {
    echo "ERROR: Failed to install system dependencies"
    exit 1
}

# Install scons
echo "Installing scons..."
sudo apt install -y scons || {
    echo "ERROR: Failed to install scons"
    exit 1
}

# Download and extract Sundials 7.0.0
echo "Downloading and extracting Sundials 7.0.0..."
mkdir -p ~/Downloads/sundials
cd ~/Downloads/sundials

# Check if already downloaded
if [ ! -f "sundials-7.0.0.tar.gz" ]; then
    wget https://github.com/LLNL/sundials/releases/download/v7.0.0/sundials-7.0.0.tar.gz || {
        echo "ERROR: Failed to download Sundials"
        exit 1
    }
fi

# Extract if not already extracted
if [ ! -d "sundials-7.0.0" ]; then
    tar -xzf sundials-7.0.0.tar.gz || {
        echo "ERROR: Failed to extract Sundials"
        exit 1
    }
fi

cd sundials-7.0.0

# Create build directory and configure Sundials
echo "Configuring Sundials build..."
rm -rf build  # Clean previous build if exists
mkdir -p build && cd build

cmake .. \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC_LIBS=OFF \
  -DBUILD_ARKODE=ON \
  -DBUILD_CVODE=ON \
  -DBUILD_CVODES=ON \
  -DBUILD_IDA=ON \
  -DBUILD_IDAS=ON \
  -DBUILD_KINSOL=ON \
  -DSUNDIALS_INDEX_SIZE=64 \
  -DSUNDIALS_BUILD_WITH_MONITORING=ON \
  -DSUNDIALS_LOGGING_ENABLE=ON \
  -DSUNDIALS_MPI_ENABLE=ON \
  -DCMAKE_C_COMPILER=mpicc \
  -DCMAKE_CXX_COMPILER=mpicxx \
  -DEXAMPLES_ENABLE=OFF \
  -DCMAKE_BUILD_TYPE=Release || {
    echo "ERROR: CMake configuration failed"
    exit 1
}

# Build and install Sundials
echo "Building Sundials (this may take several minutes)..."
make -j$(nproc) || {
    echo "ERROR: Sundials build failed"
    exit 1
}

echo "Installing Sundials..."
sudo make install || {
    echo "ERROR: Sundials installation failed"
    exit 1
}

# Update library cache
sudo ldconfig

# Clone or update the OpenDrop private repository
echo "Setting up OpenDrop repository..."
cd ~
if [ -d "opendrop_private" ]; then
    echo "OpenDrop repository already exists, updating..."
    cd opendrop_private
    git pull || {
        echo "WARNING: Failed to update repository, using existing version"
    }
else
    echo "Cloning OpenDrop repository..."
    git clone https://github.com/chinu0609/opendrop_private.git || {
        echo "ERROR: Failed to clone OpenDrop repository"
        exit 1
    }
    cd opendrop_private
fi
python3.11 -m pip install -r requirements.txt
echo "Building OpenDrop with scons..."
scons || {
    echo "ERROR: OpenDrop build failed"
    exit 1
}

# Create or update Python 3.11 virtual environment
echo "Setting up Python virtual environment..."
cd ~
if [ -d "opendrop_venv" ]; then
    echo "Virtual environment already exists, removing old version..."
    rm -rf opendrop_venv
fi

python3.11 -m venv opendrop_venv || {
    echo "ERROR: Failed to create virtual environment"
    exit 1
}

# Add OpenDrop repo path to site-packages using .pth file
echo "Adding OpenDrop to Python path..."
SITE_PACKAGES_PATH=$(find ~/opendrop_venv -type d -name "site-packages" | head -n 1)
if [ -z "$SITE_PACKAGES_PATH" ]; then
    echo "ERROR: Could not find site-packages directory"
    exit 1
fi
echo "$HOME/opendrop_private" > "$SITE_PACKAGES_PATH/opendrop.pth"

# Activate virtual environment
echo "Activating virtual environment..."
source ~/opendrop_venv/bin/activate || {
    echo "ERROR: Failed to activate virtual environment"
    exit 1
}

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip || {
    echo "WARNING: Failed to upgrade pip, continuing with existing version"
}

# Verify Python environment
echo "Python version: $(python --version)"
echo "Python path: $(which python)"
echo "Pip version: $(pip --version)"

# Install Python dependencies
echo "Installing Python dependencies from requirements.txt..."
cd ~/opendrop_private
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt || {
        echo "ERROR: Failed to install Python dependencies"
        echo "Attempting to install individual packages..."
        # Try installing common dependencies individually
        pip install numpy scipy matplotlib gtk3 || {
            echo "ERROR: Failed to install basic dependencies"
            exit 1
        }
    }
else
    echo "WARNING: requirements.txt not found, attempting to install common dependencies..."
    pip install numpy scipy matplotlib || {
        echo "ERROR: Failed to install basic dependencies"
        exit 1
    }
fi

# Verify OpenDrop is accessible
echo "Checking if OpenDrop module is accessible..."
python -c "import sys; print('Python path:'); [print('  ' + p) for p in sys.path]" || {
    echo "WARNING: Failed to print Python path"
}

echo "Testing OpenDrop import..."
python -c "import opendrop; print('OpenDrop import successful')" || {
    echo "ERROR: OpenDrop module cannot be imported"
    echo "Checking if opendrop_private is in the Python path..."
    python -c "import sys; print('opendrop_private in path:', any('opendrop_private' in p for p in sys.path))"
    exit 1
}

# Run OpenDrop
echo "Running OpenDrop application..."
echo "Note: The application window should open. Close it to complete the script."
python -m opendrop || {
    echo "ERROR: Failed to run OpenDrop application"
    echo "Trying alternative launch method..."
    python -c "import opendrop; opendrop.main()" || {
        echo "ERROR: Alternative launch method also failed"
        exit 1
    }
}

echo "OpenDrop installation and launch complete!"
echo "Virtual environment is located at: ~/opendrop_venv"
echo "To run OpenDrop in the future, use:"
echo "  source ~/opendrop_venv/bin/activate"
echo "  cd ~/opendrop_private"
echo "  python -m opendrop"

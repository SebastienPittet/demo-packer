#! /bin/bash

# Heavily inspired from https://github.com/tash-had/flask-deploy-script

# git config
GIT_REPO_OWNER="SebastienPittet"
GIT_REPO_NAME="demo-webapp"
GIT_BRANCH="master"

# vm config
VM_APP_DIR="/opt"
VM_PROJECT_PATH=""
VM_NGINX_PATH='/etc/nginx'
VM_PY_PATH="/usr/bin/python3.9"

# deployment config
DEPLOYMENT_ENV="development"
DEPLOYMENT_PORT="5000"

# project config
PROJECT_LABEL="demo-webapp"
PROJECT_TEST_FOLDER="app/tests"
PROJECT_APP_MODULE_FILE="app/app.py"
PROJECT_APP_VARIABLE="app"
PROJECT_PARENT_FOLDER="."


function setup_vm() {
    printf "***************************************************\n\t\tSetup VM \n***************************************************\n"
    # Update and upgrade packages
    echo ======= Updating packages ========
    sudo apt-get update && sudo apt-get upgrade -y

    # Export language locale settings
    echo ======= Exporting language locale settings =======
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8

    # Install basic requirements
    echo ======= Installing tools =======
    sudo apt-get install -y git python3 python3-pip
}


function setup_venv() {
    printf "***************************************************\n\t\tSetting up Venv \n***************************************************\n"
    # Install virtualenv
    echo ======= Installing virtualenv =======
    pip3 install virtualenv

    # Create virtual environment and activate it
    echo ======== Creating virtual env =======
    virtualenv -p $VM_PY_PATH $VM_APP_DIR/venv

    echo ======== Activating virtual env =======
    source $VM_APP_DIR/venv/bin/activate
}


function clone_app_repository() {
    printf "***************************************************\n\t\tFetching Code \n***************************************************\n"
    # Clone and access project directory
    if [[ -d $VM_PROJECT_PATH ]]; then
        echo ======== Removing existing project files at $VM_PROJECT_PATH ========
        sudo rm -rf $VM_PROJECT_PATH
    fi

    cd $VM_APP_DIR

    if [ $PROJECT_PARENT_FOLDER == "." ]; then
        echo ======== Cloning repo ========
        echo git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_LABEL && cd $PROJECT_LABEL
        git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_LABEL && cd $PROJECT_LABEL
    else
        echo ======== Cloning repo and keeping only files "in" $PROJECT_PARENT_FOLDER ========
        git clone -b $GIT_BRANCH $GIT_CLONE_URL $PROJECT_LABEL && cd $PROJECT_LABEL && git filter-branch --subdirectory-filter $PROJECT_PARENT_FOLDER
    fi
}


function setup_dependencies() {
    printf "***************************************************\n\t\tInstalling dependencies \n***************************************************\n"

    requirements_file="$VM_PROJECT_PATH/requirements.txt"

    if [ -f "$requirements_file" ]; then
        echo ======= requirements.txt found ========
        echo ======= Installing required packages ========
        pip3 install -r $requirements_file
    else
        echo ======= No requirements.txt found ========
        echo ======= Installing Flask and gunicorn with pip3 ========
        pip3 install Flask
        pip3 install gunicorn
    fi
}


# Run tests
function run_tests() {
    printf "***************************************************\n\t\tRunning tests \n***************************************************\n"

    test_folder="$VM_PROJECT_PATH/$PROJECT_TEST_FOLDER"
    if [[ -d $test_folder ]]; then
        echo ====== Installing nose ========
        pip install nose
        cd $test_folder
        echo ====== Starting unit tests ========
        nosetests test*
    else
        echo ====== No "test" folder found ========
    fi
}


# Create and Export required environment variable
function setup_env() {
    printf "***************************************************\n\t\tSetting up environment \n***************************************************\n"

    echo ======= Writing environment variables to "$VM_PROJECT_PATH/.env" ========
    sudo cat > $VM_PROJECT_PATH/.env << EOF
    export APP_CONFIG=${DEPLOYMENT_ENV}
    export FLASK_APP=${PROJECT_APP_MODULE_FILE}
EOF
    echo ======= Exporting the environment variables from "$VM_PROJECT_PATH/.env" ========
    source $VM_PROJECT_PATH/.env
}


# Install and configure nginx
function setup_nginx() {
    printf "***************************************************\n\t\tSetting up nginx \n***************************************************\n"
    echo ======= Installing nginx =======
    sudo apt-get install -y nginx

    # Configure nginx routing
    echo ======= Removing default config =======
    sudo rm -rf $VM_NGINX_PATH/sites-available/default
    sudo rm -rf $VM_NGINX_PATH/sites-enabled/default

    echo ======= Removing previous config =======
    sudo rm -rf $VM_NGINX_PATH/sites-enabled/$PROJECT_LABEL

    echo ======= Creating new config file =======
    sudo touch $VM_NGINX_PATH/sites-available/$PROJECT_LABEL

    echo ======= Create a symbolic link of the config file to sites-enabled =======
    sudo ln -s $VM_NGINX_PATH/sites-available/$PROJECT_LABEL $VM_NGINX_PATH/sites-enabled/$PROJECT_LABEL

    echo ======= Writing nginx configurations to config file =======
    sudo cat >$VM_NGINX_PATH/sites-enabled/$PROJECT_LABEL <<EOL
   server {
            location / {
                proxy_pass http://localhost:${DEPLOYMENT_PORT};
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
            }
    }
EOL
    # Ensure nginx server is running
    echo ====== Restarting nginx ========
    sudo /etc/init.d/nginx restart

    echo ====== Checking nginx status ========
    sudo /etc/init.d/nginx status
}


# Add a launch script
function create_launch_script () {
    printf "***************************************************\n\t\tCreating a Launch script \n***************************************************\n"

    echo ====== Fetching all processes deployed on port $DEPLOYMENT_PORT ========
    gunicorn_pid=`ps ax | grep gunicorn | grep $DEPLOYMENT_PORT | awk '{split($0,a," "); print a[1]}' | head -n 1`

    echo ====== Getting module name ========
    module_name=${PROJECT_APP_MODULE_FILE%.*}
    module_name=${module_name##*/}
    module_path="$VM_PROJECT_PATH/$module_name"

    echo ====== Writing launch script ========
    sudo cat > $VM_PROJECT_PATH/launch.sh <<EOF
    #!/bin/bash
    echo ====== Starting launch script ========
    cd $VM_PROJECT_PATH

    echo ====== Processing environment variables ========
    source $VM_PROJECT_PATH/.env

    echo ====== Activating virtual environment ========
    source $VM_APP_DIR/venv/bin/activate

    if [ ! -z $gunicorn_pid ]; then
        echo ====== Killing previously deployed instances on port $DEPLOYMENT_PORT ========
        sudo kill $gunicorn_pid
    else
        echo ====== Found no previously deployed instances on port $DEPLOYMENT_PORT ========
    fi

    echo ====== Deploying build $DEPLOYMENT_ENV of $GIT_REPO_NAME on port $DEPLOYMENT_PORT ========
    sudo $VM_APP_DIR/venv/bin/gunicorn -b 0.0.0.0:$DEPLOYMENT_PORT --env APP_CONFIG=${DEPLOYMENT_ENV} --daemon ${module_name}:$PROJECT_APP_VARIABLE
    printf "\n\n\n\n"
    echo ====== PROBLEMS? RUN \"$VM_APP_DIR/venv/bin/gunicorn -b 0.0.0.0:$DEPLOYMENT_PORT ${module_path}:$PROJECT_APP_VARIABLE\" FOR MORE LOGS ========
    printf "***************************************************\n\t\tDeployment Completed. \n***************************************************\n"
EOF

    echo ====== Giving user rights to execute launch script ========
    sudo chmod 744 $VM_PROJECT_PATH/launch.sh

    echo ====== Listing all file metadata about launch script =======
    ls -la $VM_PROJECT_PATH/launch.sh
}

# Serve the web app through gunicorn
function launch_app() {
    sudo bash $VM_PROJECT_PATH/launch.sh
}

# Gunicorn as SystemD service
function create_service_gunicorn() {
  printf "***************************************************\n\t\tCreating Gunicorn Service \n***************************************************\n"  

  echo ====== Creation of /etc/systemd/system/$PROJECT_LABEL.service ========
  sudo cat > /etc/systemd/system/$PROJECT_LABEL.service <<EOF
  [Unit]
  Description=demo-webapp
  After=network.target

  [Service]
  Type=simple
  # the specific user that our service will run as
  User=www-data
  Group=www-data
  # another option for an even more restricted service is
  # DynamicUser=yes
  # see http://0pointer.net/blog/dynamic-users-with-systemd.html
  WorkingDirectory=$VM_PROJECT_PATH
  ExecStart=$VM_APP_DIR/venv/bin/gunicorn 
  ExecReload=/bin/kill -s HUP $MAINPID
  KillMode=mixed
  TimeoutStopSec=5
  PrivateTmp=true
  Restart=always

  [Install]
  WantedBy=multi-user.target
EOF
  sudo systemctl enable --now $PROJECT_LABEL.service
}


function check_last_step() {
    if [ $1 -ne 0 ]; then
        printf "Exiting early because the previous step has failed.\n"
        printf "***************************************************\n\t\tDeployment Failed. \n***************************************************\n"
        exit 2
    fi
}

function set_dependent_config() {
    printf "***************************************************\n\t\tConfiguring script variables\n***************************************************\n"

    # set values of variables that depend on the arguments given to the script

    echo ====== Configuring git variables ========
    GIT_CLONE_URL="https://github.com/$GIT_REPO_OWNER/$GIT_REPO_NAME.git"

    PROJECT_LABEL="$GIT_REPO_NAME-$DEPLOYMENT_ENV-$DEPLOYMENT_PORT"
    echo ====== Set PROJECT_LABEL as $PROJECT_LABEL ========

    VM_PROJECT_PATH="$VM_APP_DIR/$PROJECT_LABEL"
    echo ====== Set project path as $VM_PROJECT_PATH ========
}

# RUNTIME

# Set variables using given arguments
set_dependent_config $*

setup_vm
check_last_step $?

setup_venv
check_last_step $?

clone_app_repository
check_last_step $?

setup_env
check_last_step $?

setup_dependencies
check_last_step $?

run_tests
check_last_step $?

setup_nginx
check_last_step $?

create_launch_script
check_last_step $?

create_service_gunicorn
check_last_step $?

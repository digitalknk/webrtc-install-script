#!/usr/bin/env bash
if [ "$(uname)" == "Darwin" ]; then
    echo "Unfortunately this installation script is not fully supported on MacOS. Please check the repo for updates and manual installation instructions."       
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # PROMPT USER FOR INSTALL CONFIRMATION #
    echo "This will install the Message360 WebRTC client, configured for use with the PHP Helper LIbrary."
    echo "Please make sure you are running this from within the location that you are planning to run this from."
    # Check PHP version prior to starting since Laravel requires 5.6 and newer.
    echo "Checking your version of PHP is 5.6 or newer."
    PHP_VERSION="$(php --version)"
    echo ${PHP_VERSION}
    echo -n "Is your version of PHP 5.6 or newer? Type yes if it is 5.6 or newer or no if it is lower than 5.6 and press [ENTER]: "
    read choice
    php_error="Installation canceled, exiting install. Please make sure you have a version of GREATER than PHP 5.6 installed"
    if [ $choice == 'yes' ]; then
        echo -n "Do you want to continue? Type yes or no and press [ENTER]: "
        read choice
        cancel_error="Installation canceled, exiting install."
        if [ $choice == 'yes' ]; then
            # DOWNLOAD WEBRTC SOURCE CODE AND MESSAGE360 HELPER LIBRARY #
            echo 'Performing install... Downloading source code.'
            git clone https://github.com/danielpark-ytel/message360-webrtc.git webrtc
            cd webrtc
            echo 'Downloading Message360 Helper Library PHP-V2'
            git clone https://github.com/mgrofsky/message360-API-V2-PHP.git m360-php
            cd m360-php
            # MAKE SCRIPTS DIRECTORY AND CREATE HELPER LIBRARY FILES #
            mkdir scripts
            cd scripts
            touch accessToken.php authenticateNumber.php checkFunds.php
            cd ../
            # CHECK FOR COMPOSER INSTALL AND INSTALL IF MISSING, RUN COMPOSER #
            command -v composer >/dev/null && echo "Composer is already installed." && composer self-update && composer install || { 
                echo -n 'Composer was not found and is required, do you want to install? [yes/no]: '
                read choice
                if [ $choice == 'yes' ]; then
                    echo 'Installing Composer...'
                    curl -s https://getcomposer.org/installer | php
                    mv composer.phar composer
                    composer about
                    echo 'Composer installed successfully.'
                    composer install
                else
                    if [ $choice == 'no' ]; then
                        echo $cancel_error
                        exit 1
                    fi
                fi
            }
            # PROMPT FOR SID AND TOKEN #
            echo -n "Enter your Message360 Account SID (Please make sure there are no spaces or extra characters): "
            read account_sid
            while [ ${#account_sid} -ne 36 ]; do
                echo -n "Not a valid Account SID. Your Account SID should be 36 characters in length. Please try again: "
                read account_sid
            done
            echo -n "Enter your Message360 Auth Token (Please make sure there are no spaces or extra characters): "
            read auth_token
            while [ ${#auth_token} -ne 32 ]; do 
                echo -n "Not a valid Auth Token. Your Auth Token should be 32 characters in length. Please try again: "
                read auth_token
            done
            # PRINT REQUIRED PHP CODE TO HELPER LIBRARY FILES #
            echo 'Configuring Helper Library files for usage.'
            cd scripts 
            # PHP code for accessToken.php #
            echo "
            <?php
            require_once '../vendor/autoload.php';
            \$client = new Message360Lib\Message360Client('$account_sid','$auth_token');
            \$wrtc = \$client->getWebRTC();
            \$collect['accountSid'] = '$account_sid';
            \$collect['authToken'] = '$auth_token';
            \$result = \$wrtc->createToken(\$collect);
            echo json_encode(\$result);" >> accessToken.php
            # PHP code for checkFunds.php #
            echo "
            <?php
            require_once '../vendor/autoload.php';
            \$client = new Message360Lib\Message360Client('$account_sid','$auth_token');
            \$wrtc = \$client->getWebRTC();
            \$collect['accountSid'] = '$account_sid';
            \$collect['authToken'] = '$auth_token';
            \$result = \$wrtc->createCheckFunds(\$collect);
            echo json_encode(\$result);" >> checkFunds.php
            # PHP code for authenticateNumber.php #
            echo "
            <?php
            require_once '../vendor/autoload.php';
            \$client = new Message360Lib\Message360Client('$account_sid','$auth_token');
            \$wrtc = \$client->getWebRTC();
            \$collect['accountSid'] = '$account_sid';
            \$collect['authToken'] = '$auth_token';
            \$input = file_get_contents('php://input');
            \$request = json_decode(\$input);
            \$phone_number = \$request->phone_number;
            \$collect['phoneNumber'] = \$phone_number;
            \$result = \$wrtc->createCheckFunds(\$collect);
            echo json_encode(\$result);" >> authenticateNumber.php
            # ADD PHP URL'S TO APP SOURCE CODE #
            sed -ie "s/\$rootScope\.tokenUrl = '';/\$rootScope\.tokenUrl = 'm360-php\/scripts\/accessToken\.php';/g" ./../../src/js/verto.module.js
            sed -ie "s/\$rootScope\.fundUrl = '';/\$rootScope\.fundUrl = 'm360-php\/scripts\/checkFunds\.php';/g" ./../../src/js/verto.module.js
            sed -ie "s/\$rootScope\.numberUrl = '';/\$rootScope\.numberUrl = 'm360-php\/scripts\/authenticateNumber\.php';/g" ./../../src/js/verto.module.js
            # TEMPORARY: CHANGE CONFIG ENVIRONMENT TO DEVELOPMENT #
            sed -ie 's/public static \$environment = Environments::PRODUCTION/public static \$environment = Environments::PREPRODUCTION/g' ./../src/Configuration.php
            cd ../../;
            command -v node >/dev/null && echo "Node.js is already installed, checking for updates.." && npm install npm@latest -g || { 
                echo -n 'Node.js was not found and is required, do you want to install? [yes/no]: '
                read choice
                if [ $choice == 'yes' ]; then
                    echo "npm install"
                else
                    if [ $choice == 'no' ]; then
                        echo $cancel_error
                        cd ../ && rm -rf webrtc
                        exit 1
                    fi
                fi
            }
            # INSTALL BOWER IF NOT INSTALLED #
            command -v bower >/dev/null && echo "Bower is installed, continuing with build." || {
                echo -n "Bower was not found and is required, do you want to install? [yes/no]: "
                read choice
                if [ $choice == 'yes' ]; then
                    npm install -g bower
                else 
                    if [ $choice == 'no' ]; then
                        echo $cancel_error
                        exit 1
                    fi
                fi
            }
            # RUN NPM INSTALL AND BOWER INSTALL #
            npm install && bower install
            # RUN GRUNTFILE.JS #
            grunt
        else
            if [ $choice == 'no' ]; then
                echo $cancel_error
                exit 1
            fi
        fi
    else
        if [ $choice == 'no' ]; then
            echo $php_error
            exit 1
        fi
    fi
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    echo "Unfortunately this installation script does not currently work on Windows right now. Please check the repo for updates."
fi
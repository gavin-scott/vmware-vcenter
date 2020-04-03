pipeline {
 agent { label 'jenkins-d1' }
 environment {
        PATH = "/usr/pgsql-9.6/bin:$PATH"
    }

   stages {
      stage('Build') {
         steps {
            echo env.PATH
            sh  '''#!/bin/bash --login
                   export BUNDLE_GEMFILE=${WORKSPACE}/Gemfile
                   export PATH=$PATH
                   export PUPPET_GEM_VERSION='5.3.4'
                   rvm use 2.3.4 --install --binary --fuzzy
                   gem update --system
                   gem install bundler
                   bundle install
                   bundle exec rake 
              '''
         }
      }
   }
}

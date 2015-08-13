# travis-ci-template
This is how we build our apps for internal usage

## Our CI process includes:

1. On each commit GitHub tells Travis to start build;
2. Travis parallelize build for each White-Label of our app (we have few);
3. Travis uses my scripts to set-up environment: tell project what servers should it request (we have development, staging, production servers), load provisioning profiles from the iTunes Developer, find and set the right profile for current builds (every environment have own bundle ID), change application name, development team id, changes entitlements (we have Today Widget) and many more.
3. Than it build APP file (for our QA, that use Appium for testing);
4. And builds IPA file to provision it on beta-users devices (we have separated Enterprise developer account for that);
5. Both files are sent to our build storage: https://github.com/Nebo15/nebo15.buildserver.web

After that we plan to make webhook to the server in our office, so it would run Appium tests automatically, but right now thats manual job. (We plan to make web service for that.) And then our tests runs inside my Vagrant box.
